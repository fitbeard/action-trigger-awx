FROM python:3.8-alpine

ADD requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

RUN apk update \
  && apk upgrade \
  && apk add bash \
  && rm -rf /var/cache/*/*
