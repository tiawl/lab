ARG FROM

FROM ${FROM}

ARG USER
ARG KEY_NAME
ARG KEY_DIR

USER ${USER}

RUN <<END_OF_RUN
    set -eux
    ln -s "${KEY_DIR}/${KEY_NAME}" "/home/${USER}/.ssh/${KEY_NAME}"
    ln -s "${KEY_DIR}/${KEY_NAME}.pub" "/home/${USER}/.ssh/${KEY_NAME}.pub"
END_OF_RUN
