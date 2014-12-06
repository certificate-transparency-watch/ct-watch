FROM howareyou/ruby:2.0.0-p247
MAINTAINER tom@tom-fitzhenry.me.uk

RUN apt-get install -y postgresql-server-dev-all

ADD . /src
WORKDIR /src

RUN \
    . /.profile ;\
    bundle install --deployment

CMD . /.profile && bundle exec thin start --threaded --port 80
