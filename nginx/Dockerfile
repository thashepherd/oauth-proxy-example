FROM nginx:stable-alpine3.19-slim

WORKDIR /usr/local/bin
COPY . /usr/local/bin

EXPOSE 80

CMD nginx -c /usr/local/bin/nginx.conf -g "daemon off;"
