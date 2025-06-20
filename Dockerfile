# Use a standard Ubuntu image as the base
FROM ubuntu:latest

# Set environment variables to prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies: git, jq for the scripts, and shellcheck for linting
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    jq \
    shellcheck \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -m -s /bin/bash user

# Set the working directory for the user
WORKDIR /home/user

# FIX: Copy the repository files AND set the owner to the 'user' at the same time.
COPY --chown=user:user . .

# Now, switch to the non-root user.
USER user

# Run the installer script as the user, who now owns the files and can modify them.
RUN chmod +x install.sh uninstall.sh && \
    ./install.sh

# Set the default command to start a login shell.
# The "-l" flag is crucial as it ensures .bashrc is sourced, activating your colors and aliases.
CMD ["/bin/bash", "-l"]
