FROM ruby:2.3-alpine
MAINTAINER Nikhil Narula

ENV DEBIAN_FRONTEND noninteractive

ADD . $HOME

RUN gem build fakes3.gemspec && gem install fakes3-0.2.5.gem

# run fake-s3
RUN mkdir -p /fakes3_root
ENTRYPOINT ["bin/fakes3"]
CMD ["-r",  "/fakes3_root", "-p",  "4569"]
EXPOSE 4569
