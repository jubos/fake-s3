## Introduction
FakeS3 is a lightweight server that responds to the same calls Amazon S3 responds to.  
It is extremely useful for testing of S3 in a sandbox environment without actually
making calls to Amazon, which not only require network, but also cost you precious dollars.  

For now there is a basic file store backend.

FakeS3 doesn't support all of the S3 command set, but the basic ones like put, get,
list, copy, and make bucket are supported.  More coming soon.

## Installation
    gem install fakes3

## Running
To run a fakes3 server, you just specify a root and a port.

    fakes3 -r /mnt/fakes3_root -p 4567

## Connecting to FakeS3

Take a look at the test cases to see client example usage.  For now, FakeS3 is
mainly tested with s3cmd, aws-s3 gem, and right_aws.  There are plenty more
libraries out there, and please do mention other clients.

## Running Tests
In order to run the tests add the following line to your /etc/hosts:

    127.0.0.1 s3.localhost

Then start the test server using

    rake test_server


Then in another terminal window run

    rake test

It is a TODO to get this to be just one command
