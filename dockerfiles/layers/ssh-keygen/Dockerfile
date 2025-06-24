ARG FROM

FROM ${FROM}

ARG KEY_NAME
ARG KEY_DIR
ARG USER

USER root

RUN <<END_OF_RUN
    set -eux
    if ! apk info -e openssh-keygen > /dev/null
    then
        pkgs='openssh-keygen'
    fi
    if [ -n "${pkgs:-}" ]
    then
        set -f
        apk --no-cache add ${pkgs:-}
        set +f
    fi
END_OF_RUN

USER ${USER}

RUN <<END_OF_RUN
    set -eux
    mkdir -p "${KEY_DIR}"
    # generate key
    ssh-keygen -q -t rsa -N '' -f "${KEY_DIR}/${KEY_NAME}"
    cat "${KEY_DIR}/${KEY_NAME}.pub" >> "${KEY_DIR}/authorized_keys"
END_OF_RUN
