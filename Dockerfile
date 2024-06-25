# 25JUN2024 1800 1.24gb / 12mb
FROM keycloak/keycloak:21.1.1 AS keycloak
FROM python:3.12-slim-bookworm AS python-base

# Python flags from https://bmaingret.github.io/blog/2021-11-15-Docker-and-Poetry
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1
# Set environment variables
ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_VERSION=1.8.3 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_OPTIONS_NO_PIP=true 

ENV SERVICE_NAME=oauth-secured-app
ENV PATH="$POETRY_HOME/bin:$PATH"
ENV KEYCLOAK_ADMIN=admin
ENV KEYCLOAK_ADMIN_PASSWORD=admin

RUN apt-get update -qqy \
    && apt-get -qqy upgrade \
    && apt-get install -qqy curl wget default-jre-headless \
    && apt-get clean

RUN --mount=type=cache,target=/root/.cache \
    wget https://github.com/oauth2-proxy/oauth2-proxy/releases/download/v7.6.0/oauth2-proxy-v7.6.0.linux-arm64.tar.gz \
    && tar xvzf oauth2-proxy-v7.6.0.linux-arm64.tar.gz \
    && rm oauth2-proxy-v7.6.0.linux-arm64.tar.gz

RUN --mount=type=cache,target=/root/.cache \
    curl -sSL https://install.python-poetry.org | python -

# Create user + home directory
RUN useradd --create-home --shell /bin/bash --uid 1001 $SERVICE_NAME

# Install Keycloak
COPY --from=keycloak --chown=$SERVICE_NAME /opt/keycloak/ /home/$SERVICE_NAME/app/keycloak/

# Add state: database containing preconfigured realm + user 
ADD --chown=$SERVICE_NAME h2 /home/$SERVICE_NAME/app/keycloak/data/h2/
RUN /home/$SERVICE_NAME/app/keycloak/bin/kc.sh build

# Install application dependencies
WORKDIR /home/$SERVICE_NAME/app
COPY /poetry.lock /pyproject.toml ./
RUN poetry env use 3.12
RUN --mount=type=cache,target=/root/.cache \
    poetry install --only main

# Copy application
COPY --chown=$SERVICE_NAME . /home/$SERVICE_NAME/app

#COPY --from=keycloak /opt/jboss/ /opt/jboss/

USER $SERVICE_NAME

EXPOSE 4180 8080 8501 8502

ENTRYPOINT ["poetry", "run", "supervisord"]


