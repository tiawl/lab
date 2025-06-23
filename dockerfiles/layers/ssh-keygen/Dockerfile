ARG FROM

FROM ${FROM}

ARG KEY_NAME
ARG USER

USER root

RUN <<END_OF_RUN
    set -eux
    apk --no-cache add openssh-keygen
END_OF_RUN

USER ${USER}

RUN <<END_OF_RUN
    set -eux
    mkdir -p ~/.ssh
    # generate key
    ssh-keygen -q -t rsa -N '' -f ~/.ssh/"${KEY_NAME}"
    cat ~/.ssh/"${KEY_NAME}.pub" >> ~/.ssh/authorized_keys
END_OF_RUN
