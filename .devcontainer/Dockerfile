FROM ubuntu:22.04

# Configuration
ARG NODE_VERSION=20
# see https://github.com/nvm-sh/nvm/releases for the latest version
ARG NVM_VERSION=v0.40.2

# Set the default shell to bash
SHELL ["/bin/bash", "-c"]

# An env variable to identify if you are in the dev-container
ENV STARTERKIT_DEVCONTAINER=1
# Conan's cache directory
ENV CONAN_HOME=/.conan2
# uv's tool directories
ENV UV_BASE_DIR=/usr/local/share/uv
ENV UV_INSTALL_DIR=$UV_BASE_DIR/bin
ENV UV_TOOL_DIR=$UV_BASE_DIR/tool
ENV UV_TOOL_BIN_DIR=$UV_BASE_DIR/tool/bin
# Ensure the virtual environment is activated by default
ENV PATH="$UV_INSTALL_DIR:$UV_TOOL_BIN_DIR:/opt/venv/bin:$PATH"
# Set noninteractive mode for apt-get
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
# Install sudo & curl as it's required in scripts
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt -y update && apt -y upgrade && apt -y install sudo curl
# For WASM build, install nvm & node
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN bash -c "source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION"
# Dev env setup
# Setup the project
COPY ./setup.sh ./
COPY ./env/scripts/install_uv.sh ./env/scripts/install_uv.sh
RUN ./setup.sh && rm -f ./setup.sh && rm -rf ./env

# Users: mirror the host user inside the container
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ENV HOST_USER=${USERNAME}

# The base image may already own the uid/gid (e.g. 'ubuntu' = 1000), so only create what is missing.
RUN set -euo pipefail; \
    host_home=$(getent passwd "${HOST_USER}" | cut -d: -f6 || true); \
    if [ -z "${host_home}" ]; then \
      if ! getent group "${USER_GID}" >/dev/null 2>&1; then \
        groupadd --gid "${USER_GID}" "${HOST_USER}"; \
      fi; \
      useradd --uid "${USER_UID}" --gid "${USER_GID}" -m "${HOST_USER}"; \
      host_home="/home/${HOST_USER}"; \
    fi; \
    echo "${HOST_USER} ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/${HOST_USER}" \
    && chmod 0440 "/etc/sudoers.d/${HOST_USER}" \
    && chsh -s /bin/bash "${HOST_USER}" \
    && chsh -s /bin/bash root \
    && mkdir -p "${host_home}/.ssh" "${CONAN_HOME}" \
    && chown -R "${HOST_USER}:${USER_GID}" "${host_home}/.ssh" "${CONAN_HOME}" "${UV_BASE_DIR}" \
    && chmod 700 "${host_home}/.ssh" \
    && ln -snf "${host_home}/.ssh" /root/.ssh

USER ${HOST_USER}
WORKDIR /home/${HOST_USER}
# set ENTRYPOINT for reloading nvm-environment
ENTRYPOINT ["bash", "-c", "source $NVM_DIR/nvm.sh && exec \"$@\"", "--"]
CMD ["/bin/bash"]
