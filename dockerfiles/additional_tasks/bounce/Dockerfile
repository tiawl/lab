ARG FROM

FROM ${FROM}

ARG USER
ARG KEY_NAME
ARG KEY_DIR

USER ${USER}

RUN <<END_OF_RUN
    set -eux
    ln -s "${KEY_DIR}/${KEY_NAME}" ~/.ssh/"${KEY_NAME}"
    ln -s "${KEY_DIR}/${KEY_NAME}.pub" ~/.ssh/"${KEY_NAME}.pub"
    for hostname in controller
    do
        printf 'Host %s\n    Hostname %s\n    User %s\n    IdentityFile ~/.ssh/int-ssh-main\n\n' "${hostname}" "${hostname}" "${USER}"
    done >> ~/.ssh/config
END_OF_RUN
