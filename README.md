This is an example for securing applications behind Keycloak SSO.

All credit for writing this example goes to layandreas. This fork does the same thing, but builds faster and produces an image that's half the size.

# Getting Started

**Note: When running locally, you may need to change the `oauth2-proxy` binary in the Dockerfile to one that works on your machine from the [oauth2-proxy releases page](https://github.com/oauth2-proxy/oauth2-proxy/releases).**

**Note: The provided Keycloak config in /h2 is specific to Keycloak 21.1.1 and will not work with more recent versions.**

Use `docker compose` to build and run the containers:

```bash
docker compose up --build
```

Then navigate to `localhost/app1` or `localhost/app2` to start the authentication flow. The login user and password are both set to "test":

![](auth_flow.gif)


# What does it do?

**Dockerfile**: 

1. Starts a pre-configured Keycloak instance (config is stored in ./h2/ folder and copied to container at build-time)
2. Starts oauth2-proxy
3. Starts 2 streamlit apps

All processes are run with `supervisor` (see supervisord.conf)

**nginx/Dockerfile**:
Proxies all requests through and requests authentication through `oauth2-proxy`
