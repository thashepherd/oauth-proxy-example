# Download & extract oauth2-proxy
FROM alpine AS oauth2-proxy-base
ENV OAUTH2_PROXY_VERSION="7.4.0"
ENV OAUTH2_PROXY_DIR="/oauth2-proxy"

# TODO tie more explicitly to supervisord.conf
RUN mkdir -p $OAUTH2_PROXY_DIR
RUN wget https://github.com/oauth2-proxy/oauth2-proxy/releases/download/v$OAUTH2_PROXY_VERSION/oauth2-proxy-v$OAUTH2_PROXY_VERSION.linux-arm64.tar.gz \
    && tar xvzf oauth2-proxy-v$OAUTH2_PROXY_VERSION.linux-arm64.tar.gz \
    && rm oauth2-proxy-v$OAUTH2_PROXY_VERSION.linux-arm64.tar.gz

RUN mv /oauth2-proxy-v$OAUTH2_PROXY_VERSION.linux-arm64/oauth2-proxy $OAUTH2_PROXY_DIR \
    && rm -r /oauth2-proxy-v$OAUTH2_PROXY_VERSION.linux-arm64

# Prep env vars, JRE dependency, & user
FROM python:3.12-slim-bookworm AS python-base

# Python flags from https://bmaingret.github.io/blog/2021-11-15-Docker-and-Poetry
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PYSETUP_PATH="/opt/pysetup" \
    # Used to coordinate with Poetry
    VENV_PATH="/opt/pysetup/.venv" 

ENV PATH="$VENV_PATH/bin:$PATH"

ENV SERVICE_NAME="oauth-secured-app"
ENV APPLICATION_DIRECTORY=/home/$SERVICE_NAME/app

RUN apt-get update -qqy \
    && apt-get -qqy upgrade \
    && apt-get install -qqy default-jre-headless --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash --uid 1001 $SERVICE_NAME
RUN mkdir -p $APPLICATION_DIRECTORY \
    && chown -R $SERVICE_NAME $APPLICATION_DIRECTORY


# Install Poetry & application dependencies
FROM python-base AS poetry-base
ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_VERSION=1.8.3 \
    POETRY_VIRTUALENVS_OPTIONS_NO_PIP=true \
    POETRY_HOME="/opt/poetry"

ENV PATH="$POETRY_HOME/bin:$PATH"

RUN apt-get update -qqy \
    && apt-get install -qqy curl --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR $PYSETUP_PATH
RUN --mount=type=cache,target=/root/.cache \
    curl -sSL https://install.python-poetry.org | python -

COPY /poetry.lock /pyproject.toml ./
RUN --mount=type=cache,target=/root/.cache \
    poetry install --only main --no-root --no-directory -n


# Application
# Note that we're using python-base as our base image and merely copying deps from poetry-base
FROM keycloak/keycloak:21.1.1 AS keycloak
FROM python-base AS application

ENV KEYCLOAK_ADMIN=admin \
    KEYCLOAK_ADMIN_PASSWORD=admin

# Copy Oauth2-proxy stuff
COPY --from=oauth2-proxy-base --chown=$SERVICE_NAME "/oauth2-proxy" .

WORKDIR $APPLICATION_DIRECTORY

# Keycloak
COPY --from=keycloak --chown=$SERVICE_NAME /opt/keycloak/ $APPLICATION_DIRECTORY/keycloak/
# Add state database containing preconfigured realm + user 
COPY --chown=$SERVICE_NAME h2 ./keycloak/data/h2/
RUN ./keycloak/bin/kc.sh -v build

# Copy dependencies
COPY --from=poetry-base $PYSETUP_PATH $PYSETUP_PATH

# Copy application files
COPY --chown=$SERVICE_NAME . .

USER $SERVICE_NAME

EXPOSE 4180 8080 8501 8502

ENTRYPOINT ["supervisord"]
