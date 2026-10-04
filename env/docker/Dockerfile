# Runtime image built from the project's DEB/RPM, so the container ships exactly what a user
# gets from the package. Build with env/scripts/build-docker-image.sh, which stages the package.
#
# The base must match the package kind: Debian/Ubuntu for a .deb, Amazon Linux/UBI for a .rpm.
ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE}

ARG PACKAGE_NAME=starterkit
ARG VERIFY_BINARY=starterkit-cli
ENV VERIFY_BINARY=${VERIFY_BINARY}
ENV PATH="/usr/local/${PACKAGE_NAME}/bin:${PATH}"

ARG PACKAGE_FILE
COPY ${PACKAGE_FILE} /tmp/pkg/

RUN set -eux; \
    if [ -f /etc/debian_version ]; then \
      apt-get update && apt-get install -y /tmp/pkg/*.deb && rm -rf /var/lib/apt/lists/*; \
    else \
      dnf install -y /tmp/pkg/*.rpm && dnf clean all; \
    fi; \
    rm -rf /tmp/pkg; \
    test -x "/usr/local/${PACKAGE_NAME}/bin/${VERIFY_BINARY}"

CMD ["sh", "-c", "exec \"$VERIFY_BINARY\""]
