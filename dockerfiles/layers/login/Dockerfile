ARG FROM

FROM ${FROM}

ARG USER
ARG UID

USER root

RUN <<END_OF_RUN
    set -eux
    apk --no-cache add openssh-server bash
    # fix sshd: no hostkeys available -- exiting
    ssh-keygen -A
    addgroup -S "${USER}"
    adduser -D -h "/home/${USER}" -s "$(command -v bash)" -G "${USER}" -u "${UID}" "${USER}"
    echo "${USER}:*" | chpasswd -e
END_OF_RUN

COPY copyme/ /

USER ${USER}

RUN <<END_OF_RUN
    set -eux
    mv /tmp/.bash_profile ~
    mkdir -p ~/.bash_profile.d
END_OF_RUN
