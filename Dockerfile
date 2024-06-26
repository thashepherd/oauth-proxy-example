# 25JUN2024 1800 1.24gb / 12mb
FROM python:3.12-slim-bookworm AS python-base

# Python flags from https://bmaingret.github.io/blog/2021-11-15-Docker-and-Poetry
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1

ENV SERVICE_NAME=oauth-secured-app
ENV APPLICATION_DIRECTORY=/home/$SERVICE_NAME/app

RUN apt-get update -qqy \
    && apt-get -qqy upgrade \
    && apt-get install -qqy wget default-jre-headless \
    && apt-get clean

# Create user + home directory
RUN useradd --create-home --shell /bin/bash --uid 1001 $SERVICE_NAME


# Download & extract oauth2-proxy
FROM alpine AS oauth2-proxy-base

# TODO deduplicate usage of oauth2-proxy filename & path / tie more explicitly to supervisord.conf
RUN wget https://github.com/oauth2-proxy/oauth2-proxy/releases/download/v7.6.0/oauth2-proxy-v7.6.0.linux-arm64.tar.gz \
    && tar xvzf oauth2-proxy-v7.6.0.linux-arm64.tar.gz \
    && rm oauth2-proxy-v7.6.0.linux-arm64.tar.gz

# Install Poetry & application dependencies
# This is kept as a separate base image since many similar applications don't use Poetry in their entrypoint and thus can exclude it from the final image
FROM python-base AS poetry-base
ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_VERSION=1.8.3 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_OPTIONS_NO_PIP=true
ENV PATH="$POETRY_HOME/bin:$PATH"

WORKDIR $APPLICATION_DIRECTORY

RUN apt-get install -qqy curl \
    && apt-get clean
RUN --mount=type=cache,target=/root/.cache \
    curl -sSL https://install.python-poetry.org | python -

COPY /poetry.lock /pyproject.toml ./
RUN --mount=type=cache,target=/root/.cache \
    poetry install --only main


# Application
FROM keycloak/keycloak:21.1.1 AS keycloak
FROM poetry-base AS application

ENV KEYCLOAK_ADMIN=admin \
    KEYCLOAK_ADMIN_PASSWORD=admin

WORKDIR $APPLICATION_DIRECTORY

# Copy Oauth2-proxy stuff
COPY --from=oauth2-proxy-base --chown=$SERVICE_NAME /oauth2-proxy-v7.6.0.linux-arm64/oauth2-proxy /oauth2-proxy-v7.6.0.linux-arm64/oauth2-proxy
RUN chown -R $SERVICE_NAME /oauth2-proxy-v7.6.0.linux-arm64 -v

# Install Keycloak
COPY --from=keycloak --chown=$SERVICE_NAME /opt/keycloak/ $APPLICATION_DIRECTORY/keycloak/
# Add state: database containing preconfigured realm + user 
ADD --chown=$SERVICE_NAME h2 ./keycloak/data/h2/
RUN ./keycloak/bin/kc.sh build

COPY --chown=$SERVICE_NAME . .

#COPY --from=keycloak /opt/jboss/ /opt/jboss/

USER $SERVICE_NAME

EXPOSE 4180 8080 8501 8502

ENTRYPOINT ["poetry", "run", "supervisord"]


