ARG FROM

FROM ${FROM}

ARG USER
ARG KEY_NAME
ARG KEY_DIR

USER ${USER}

RUN <<END_OF_RUN
    set -eux
    mkdir -p ~/.ssh
    ln -s "${KEY_DIR}/${KEY_NAME}" ~/.ssh/"${KEY_NAME}"
    ln -s "${KEY_DIR}/${KEY_NAME}.pub" ~/.ssh/"${KEY_NAME}.pub"
    ln -s "${KEY_DIR}/authorized_keys" ~/.ssh/authorized_keys
END_OF_RUN
