# Variant for Haskell in CPSC 312, based on https://github.com/PrairieLearnUBC/workspace_cpsc210

# Enhanced code-server workspace template for PrairieLearn.
# As discussed here: https://github.com/PrairieLearn/PrairieLearn/issues/3170
# Based on the original Dockerfiles for code-server.
# 20210630 Eric Huber - updating to 3.10.2, simplifying, fixing local testing

# It seems like the bug has been fixed, so let's try the more recent version.
# (Some extensions are broken with older versions.)
# https://github.com/PrairieLearn/PrairieLearn/issues/4036

FROM --platform=linux/amd64 codercom/code-server:4.20.0-bookworm

# On PL, we want to standardize on using 1001:1001 for the user. We change the
# "coder" account's UID and GID here so that fixuid has no work to do later.
# This speeds up container loading time drastically and avoids timeouts.
USER root
RUN export OLD_UID=$(id -u coder) && \
	export OLD_GID=$(id -g coder) && \
	export NEW_UID=1001 && \
	export NEW_GID=1001 && \
	groupmod -g 1001 coder && \
	usermod -u 1001 -g 1001 coder && \
	find /home -user $OLD_UID -execdir chown -h $NEW_UID {} + && \
	find /home -group $OLD_GID -execdir chgrp -h $NEW_GID {} + && \
	unset OLD_UID OLD_GID NEW_UID NEW_GID





# Cleaning up the cache in the same step when we install is important if you
# want to minimize the image size.
USER coder

####################################################
## Install Haskell

RUN sudo apt-get update -y
RUN sudo apt-get install -y \
    build-essential \
    curl \
    libffi-dev \
    libffi8 \
    libgmp-dev \
    libgmp10 \
    libncurses-dev \
    libncurses5 \
    libtinfo5 \
    pkg-config

# Install with HLS and set up the PATH properly.
ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1
ENV BOOTSTRAP_HASKELL_INSTALL_HLS=1
ENV BOOTSTRAP_HASKELL_ADJUST_BASHRC=1
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

# # UPDATE LTS HERE
# # Review https://www.stackage.org/ to compare ghc versions to what's available.
# ENV LTS=lts-22.31


RUN ( code-server --disable-telemetry --force \
		# Install only one extension per line.
		--install-extension haskell.haskell \
		--install-extension ms-vscode.live-server \
	) && \
	rm -rf /home/coder/.local/share/code-server/CachedExtensionVSIXs


# Prepare the entrypoints. The entrypoint.sh part is based on what code-server
# originally had, so it may need to be updated when code-server is updated. We
# avoid running fixuid if the user is root (for local testing in PL). We also
# disable auth as PL handles it.
USER root
RUN rm -f /run/fixuid.ran && \
	echo "" > /usr/bin/entrypoint.sh && chmod 0755 /usr/bin/entrypoint.sh && \
	/usr/bin/env echo -e '#!/usr/bin/env bash \n' \
	'set -eu \n' \
	'# We do this first to ensure sudo works below when renaming the user. \n' \
	'# Otherwise the current container UID may not exist in the passwd database. \n' \
	'[ $(id -u) -ne 0 ] && eval "$(fixuid -q)" \n' \
	' \n' \
	'if [ "${DOCKER_USER-}" ]; then \n' \
	'  USER="$DOCKER_USER" \n' \
	'  if [ "$DOCKER_USER" != "$(whoami)" ]; then \n' \
	'    echo "$DOCKER_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/nopasswd > /dev/null \n' \
	'    # Unfortunately we cannot change $HOME as we cannot move any bind mounts \n' \
	'    # nor can we bind mount $HOME into a new home as that requires a privileged container. \n' \
	'    sudo usermod --login "$DOCKER_USER" coder \n' \
	'    sudo groupmod -n "$DOCKER_USER" coder \n' \
	' \n' \
	'    sudo sed -i "/coder/d" /etc/sudoers.d/nopasswd \n' \
	'  fi \n' \
	'else \n' \
	'  sudo rm /etc/sudoers.d/nopasswd \n' \	
	'fi \n' \
	'\n' \
	'dumb-init /usr/bin/code-server --auth none "$@" \n' >> /usr/bin/entrypoint.sh


EXPOSE 8080


RUN /bin/sh -c echo "**** install runtime dependencies ****" && \
	sudo apt-get update && \
	sudo apt-get install -y \
	software-properties-common \
	jq \
	libatomic1 \
	net-tools \
	netcat-traditional 

RUN echo "**** clean up ****" && \
	sudo apt-get clean && \
	sudo rm -rf \
	/config/* \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

# TODO: Maybe customize the preferences to set the theme to auto-adjust to the
# browser, turn off more telemetry, etc.

# Please read the note here carefully to avoid wiping out what you installed
# in ~/.local:

# EDITOR_FOCUS_DIR should be set to the directory you want the editor to start
# up in. This is not necessarily the same as the "home" setting in the
# question's info.json file. The "home" setting determines the mount point for
# the persistent cloud storage, which will hide any contents your image
# originally had at the same path. You might want to set both EDITOR_FOCUS_DIR
# and "home" to a deeper directory than /home/coder if you want to keep the
# default home contents from the workspace image (~/.local, etc.). For
# example, using /home/coder/question will copy the question's workspace
# folder contents into an empty mount at /home/coder/question and save it for
# the student, while always reusing the initial contents of /home/coder that
# you prepared in the image. (However, if students try to customize their
# editor settings, those will get reset in between sessions this way.)
USER coder
ENV EDITOR_FOCUS_DIR="/home/coder/prairielearn/project/Project"
RUN mkdir -p "$EDITOR_FOCUS_DIR"
WORKDIR "$EDITOR_FOCUS_DIR"


RUN mkdir -p "/home/coder/.local/share/code-server/User" "/home/coder/prairielearn/project/Project"
COPY --chmod=0444 settings.json /home/coder/.local/share/code-server/User/settings.json
COPY --chmod=0666 keybindings.json /home/coder/.local/share/code-server/User/keybindings.json
COPY --chmod=0444 coder.json /home/coder/.local/share/code-server/coder.json
COPY --chmod=0444 settingsEmpty.json /home/coder/.local/share/code-server/Machine/settings.json
COPY --chmod=0555 workspaceTemplate/.scripts /home/coder/prairielearn/project/Project/.scripts
COPY --chmod=0444 workspaceTemplate/.vscode /home/coder/prairielearn/project/Project/.vscode
COPY --chmod=0444 workspaceTemplate/.lib /home/coder/prairielearn/project/Project/.lib

ENTRYPOINT ["/usr/bin/env", "sh", "/usr/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]