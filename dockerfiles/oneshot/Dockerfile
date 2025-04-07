FROM local.alpine:latest

ARG UID

RUN <<END_OF_RUN
    apk --no-cache add git findutils
    rm -rf /var/lib/apt/lists/* /var/cache/apk/* /tmp /etc/docker ${1}
    adduser -D -s /bin/sh -g nobody -u '${UID}' nobody
END_OF_RUN

USER nobody

WORKDIR /home/nobody

CMD ["busybox", "sh"]
