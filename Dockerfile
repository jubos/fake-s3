FROM ruby:2.2.0

WORKDIR /opt/fakes3

ADD Gemfile /opt/fakes3/Gemfile
ADD Gemfile.lock /opt/fakes3/Gemfile.lock
ADD fakes3.gemspec /opt/fakes3/fakes3.gemspec
ADD lib/fakes3/version.rb /opt/fakes3/lib/fakes3/version.rb
RUN bundle install

RUN mkdir -p /var/data/fakes3
ADD . /opt/fakes3

EXPOSE 80

CMD ["/opt/fakes3/bin/fakes3", "-r", "/var/data/fakes3", "-p", "80"]
