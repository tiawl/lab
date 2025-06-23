ARG FROM

FROM ${FROM}

USER root

RUN <<END_OF_RUN
    set -eux
    apk --no-cache add openssh-client
END_OF_RUN
