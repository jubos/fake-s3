FROM debian:jessie
MAINTAINER Nikhil Narula

ENV DEBIAN_FRONTEND noninteractive

# install Ruby
RUN apt-get update && apt-get install -yqq ruby rubygems-integration
ADD . $HOME

# run fake-s3
RUN mkdir -p /fakes3_root
ENTRYPOINT ["bin/fakes3"]
CMD ["-r",  "/fakes3_root", "-p",  "4569"]
EXPOSE 4569
