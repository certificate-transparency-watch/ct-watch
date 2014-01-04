FROM howareyou/ruby:2.0.0-p247
MAINTAINER tom@tom-fitzhenry.me.uk

ADD . /src
WORKDIR /src

RUN apt-get install -y postgresql-server-dev-all

RUN \
    . /.profile ;\
    bundle install --deployment

CMD . /.profile && bundle exec rackup -p 80
