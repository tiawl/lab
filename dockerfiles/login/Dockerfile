ARG FROM

FROM ${FROM}

ARG KEY_NAME
ARG SSH_HOME
ARG USER
ARG UID

RUN <<END_OF_RUN
    set -eux
    apk --no-cache add openssh-server bash
    # fix sshd: no hostkeys available -- exiting
    ssh-keygen -A
    addgroup -S "${USER}"
    adduser -D -h "$(dirname ${SSH_HOME})" -s "$(command -v bash)" -G "${USER}" -u "${UID}" "${USER}"
    echo "${USER}:*" | chpasswd -e
END_OF_RUN

USER ${USER}

RUN <<END_OF_RUN
    set -eux
    mkdir -p "${SSH_HOME}"
    # generate host key
    ssh-keygen -q -t rsa -N '' -f "${SSH_HOME}/${KEY_NAME}"
    cp "${SSH_HOME}/${KEY_NAME}.pub" "${SSH_HOME}/authorized_keys"
END_OF_RUN

COPY copyme/ /

USER root

HEALTHCHECK --start-period=3s CMD netstat -plant | grep :22 || exit 1

CMD ["/usr/sbin/sshd", "-D", "-e"]
