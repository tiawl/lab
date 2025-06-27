ARG FROM

FROM ${FROM}

USER root

RUN <<END_OF_RUN
    set -eux
    if ! apk info -e openssh-client > /dev/null
    then
        pkgs='openssh-client'
    fi
    if [ -n "${pkgs:-}" ]
    then
        set -f
        apk --no-cache add ${pkgs}
        set +f
    fi
END_OF_RUN

COPY copyme/ /
