# Dockerfile for the Color Module

# 1. Base Image: Pin to a specific version for reproducible builds.
FROM ubuntu:22.04

# 2. Environment: Set environment variables for non-interactive apt-get.
ENV DEBIAN_FRONTEND=noninteractive

# 3. Dependencies: Install all system dependencies in a single layer.
# This layer is cached unless the list of packages changes.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # For JSON parsing
    jq \
    # For 'please' alias and user management
    sudo \
    # Common development tools
    git \
    curl \
    net-tools \
    # Various archive/compression tools
    unzip \
    p7zip-full \
    unrar \
    bzip2 \
    gzip \
    xz-utils \
    unace \
    # Optional: for linting shell scripts
    # shellcheck \
    && \
    # Clean up apt cache to keep the image size down
    rm -rf /var/lib/apt/lists/*

# 4. User Creation: Create a non-root user before copying app code.
# Using ARGs allows for customization during build time.
ARG USER_NAME=patrick
ARG USER_UID=2000
RUN useradd --create-home --shell /bin/bash --uid ${USER_UID} ${USER_NAME} && \
    # Grant passwordless sudo privileges to the new user.
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME} && \
    chmod 0440 /etc/sudoers.d/${USER_NAME}

# 5. Application Code: Copy the source code into the container.
# Set the working directory first.
WORKDIR /patrick/color
# This COPY invalidates the cache when source files change, but all prior layers remain cached.
COPY . .

# 6. Permissions: Set correct ownership and permissions for the app files.
# This must be done as root BEFORE switching to the non-root user.
# Grant execute permissions to scripts and give ownership of the app to the user.
#RUN chmod +x install.sh install_aliases.sh uninstall.sh && \
#    chown -R ${USER_NAME}:${USER_NAME} /app

# 7. Switch User: Switch to the non-root user for subsequent commands.
# This is a key security best practice.
USER ${PATRICK}

# Set HOME to ensure scripts and tools run in the user's context.
ENV HOME=/home/${PATRICK}

# 8. Installation: Run the installation scripts as the non-root user.
# The scripts will modify the user's HOME directory (~/.bashrc, etc.).
#RUN ./install.sh --force && \
    # The install.sh script likely creates this hook; ensure it's executable.
#    chmod +x "${HOME}/ctl_environment/install_hook.sh" && \
#    ./install_aliases.sh --force

# 9. Shell Configuration: Ensure .bashrc is sourced by login shells.
# This makes aliases and functions available in an interactive container session.
RUN echo 'source ~/.bashrc' >> ~/.bash_profile

# 10. Default Command: Start an interactive login shell.
# The '-l' flag makes it a login shell, which sources ~/.bash_profile.
CMD ["bash", "-l"]
