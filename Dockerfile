FROM docker.io/library/python:3.14-alpine AS build

ADD requirements.txt /requirements.txt
COPY patches /patches

RUN apk update \
  && apk add git

RUN python3 -m venv --upgrade-deps --system-site-packages /var/lib/awx

RUN /var/lib/awx/bin/pip3 install \
    --no-cache-dir -r /requirements.txt

RUN ls -al /patches/
RUN git -C $(/var/lib/awx/bin/python -c "import sysconfig; print(sysconfig.get_paths()['purelib'])") apply --verbose /patches/*

FROM docker.io/library/python:3.14-alpine

ENV PATH=/var/lib/awx/bin:$PATH

RUN apk update \
  && apk upgrade \
  && apk add bash jq \
  && rm -rf /var/cache/*/*

COPY --from=build --link /var/lib/awx /var/lib/awx

ADD entrypoint.sh /entrypoint.sh
ADD entrypoint.sh /usr/local/bin/awx-ci
RUN chmod +x /entrypoint.sh /usr/local/bin/awx-ci
ENTRYPOINT ["/entrypoint.sh"]
