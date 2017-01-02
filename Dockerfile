FROM alpine:3.4

RUN apk add --no-cache --update ruby ruby-dev ruby-bundler python py-pip git build-base libxml2-dev libxslt-dev
RUN pip install boto s3cmd

COPY fakes3.gemspec Gemfile Gemfile.lock /app/
COPY lib/fakes3/version.rb /app/lib/fakes3/

WORKDIR /app

RUN bundle install

COPY . /app/
