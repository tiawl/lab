ARG FROM

FROM ${FROM}

USER root

RUN <<END_OF_RUN
    set -eux
    apk --no-cache add --virtual tmux_plugins_manager_installer git
END_OF_RUN

COPY copyme/ /

ARG USER

USER ${USER}

RUN <<END_OF_RUN
    set -eux
    git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    mv /tmp/.tmux.conf ~
    for file in /tmp/.bash_profile.d/*
    do
      mv "${file}" ~/.bash_profile.d/
    done
END_OF_RUN

USER root

RUN <<END_OF_RUN
    set -eux
    apk del tmux_plugins_manager_installer
    apk --no-cache add tmux tmuxinator tmuxinator-bash-completion
    #TODO: wget -O /etc/profile.d/99completion.d/99tmux.sh https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/master/completions/tmux
END_OF_RUN
