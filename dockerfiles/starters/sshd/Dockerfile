ARG FROM

FROM ${FROM}

USER root

HEALTHCHECK --start-period=3s CMD netstat -plant | grep :22 || exit 1

CMD ["/usr/sbin/sshd", "-D", "-e"]
