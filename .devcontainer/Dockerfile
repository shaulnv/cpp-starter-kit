FROM ubuntu:22.04

# Set the default shell to bash
SHELL ["/bin/bash", "-c"]

# An env variable to identify if you are in the dev-container
ENV STARTERKIT_DEVCONTAINER=1
# Conan's cache directory
ENV CONAN_HOME=/.conan2
# Set noninteractive mode for apt-get
ENV DEBIAN_FRONTEND=noninteractive
# Install 'sudo' as it's required in scripts
RUN apt -y update && apt -y upgrade && apt -y install sudo
# Dev env setup
# Setup the project
COPY ./setup.sh ./env/requirements.txt ./
RUN ./setup.sh && rm ./setup.sh 
# Create and configure a virtual environment
RUN python3 -m venv /opt/venv
# Ensure the virtual environment is activated by default
ENV PATH="/opt/venv/bin:$PATH"
# Install dependencies within the virtual environment
RUN pip install --no-input --upgrade pip && \
    pip install --no-input -r ./requirements.txt
# Configure Conan's profile
RUN conan profile detect -e
# Clean up
RUN rm -f ./setup.sh ./requirements.txt

# Users:
# Make the host user accessable inside the container
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
# Ensure the Conan cache directory is owned by the host user
RUN chown -R $HOST_USER:$HOST_USER $CONAN_HOME

USER $HOST_USER
WORKDIR /home/$HOST_USER
CMD ["/bin/bash"]
