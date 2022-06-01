FROM t42x/awxkit_base:v1-19.4.0-stdoutfix

ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
