#!/bin/bash
apt-get update
apt-get install -y curl
curl -sL https://sentry.io/get-cli/ | bash
sentry-cli --auth-token ${SENTRY_AUTH_TOKEN} upload-dif -o opengisch -p bafu-sam /usr/lib/qgis/*/lib*.so
