FROM ubuntu:22.04

# Configuration
ARG NODE_VERSION=20

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
# Install sudo & curl as it's required in scripts
RUN apt -y update && apt -y upgrade && apt -y install sudo curl
# For WASM build, install nvm & node
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN bash -c "source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION"
# Dev env setup
# Setup the project
COPY ./setup.sh ./
COPY ./env/scripts/install_uv.sh ./env/scripts/install_uv.sh
RUN ./setup.sh && rm -f ./setup.sh && rm -rf ./env
RUN mkdir -p $CONAN_HOME

# Users:
# Make the host user accessible inside the container
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# Determine the final username
ENV USER_ORIGINAL=${GITHUB_USER:-ubuntu}
ENV HOST_USER=${USERNAME}
RUN if [ "$USERNAME" == "ubuntu" ]; then export HOST_USER="$USER_ORIGINAL"; fi

# Create the user
RUN groupadd --gid $USER_GID $HOST_USER \
    && useradd --uid $USER_UID --gid $USER_GID -m $HOST_USER \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $HOST_USER ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$HOST_USER \
    && chmod 0440 /etc/sudoers.d/$HOST_USER
# Change root's password
RUN echo 'root:1234' | chpasswd
# Make bash the default shell,
RUN chsh -s /bin/bash $HOST_USER && chsh -s /bin/bash root
# Share common folders for root and HOST_USER
RUN ln -s /home/$HOST_USER/.ssh /root/.ssh
# Ensure tools directories are owned by the host user
RUN chown -R $HOST_USER:$HOST_USER $CONAN_HOME \
    && chown -R $HOST_USER:$HOST_USER $UV_BASE_DIR
RUN chmod -R 777 $CONAN_HOME \
    && chmod -R 777 $UV_BASE_DIR

USER $HOST_USER
WORKDIR /home/$HOST_USER
# set ENTRYPOINT for reloading nvm-environment
ENTRYPOINT ["bash", "-c", "source $NVM_DIR/nvm.sh && exec \"$@\"", "--"]
CMD ["/bin/bash"]
