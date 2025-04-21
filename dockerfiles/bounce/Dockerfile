ARG FROM

FROM ${FROM}

ARG KEY_PATH

RUN <<END_OF_RUN
    set -eux
    apk --no-cache add openssh-client openssh-server
    mkdir -p "$(dirname "${KEY_PATH}")"
    ssh-keygen -q -t rsa -N '' -f "${KEY_PATH}"
END_OF_RUN

#HEALTHCHECK CMD sshd -V || exit 1

CMD ["/usr/sbin/sshd", "-D", "-e"]
