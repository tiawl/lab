ARG FROM

FROM ${FROM}

ARG USER
ARG UID

USER root

RUN <<END_OF_RUN
    set -eux
    if ! apk info -e bash > /dev/null
    then
        pkgs='bash'
    fi
    if ! apk info -e openssh-server > /dev/null
    then
        pkgs="${pkgs:-}${pkgs:+ }openssh-server"
    fi
    if [ -n "${pkgs:-}" ]
    then
        set -f
        apk --no-cache add ${pkgs}
        set +f
    fi
    # fix sshd: no hostkeys available -- exiting
    ssh-keygen -A
    addgroup -S "${USER}"
    adduser -D -h "/home/${USER}" -s "$(command -v bash)" -G "${USER}" -u "${UID}" "${USER}"
    echo "${USER}:*" | chpasswd -e
    mkdir -p "/data/${USER}"
    chown "${USER}:${USER}" "/data/${USER}"
END_OF_RUN

COPY copyme/ /

USER ${USER}

RUN <<END_OF_RUN
    set -eux
    mv /tmp/.bash_profile ~
    mkdir -p ~/.bash_profile.d
END_OF_RUN
