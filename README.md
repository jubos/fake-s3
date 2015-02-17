## Introduction
FakeS3 is a lightweight server that responds to the same calls Amazon S3 responds to.
It is extremely useful for testing of S3 in a sandbox environment without actually
making calls to Amazon, which not only require network, but also cost you precious dollars.

The goal of Fake S3 is to minimize runtime dependencies and be more of a
development tool to test S3 calls in your code rather than a production server
looking to duplicate S3 functionality.  Trying RiakCS, ParkPlace/Boardwalk, or
Ceph might be a place to start if that is your goal.

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
libraries out there, and please do mention if other clients work or not.

Here is a running list of [supported clients](https://github.com/jubos/fake-s3/wiki/Supported-Clients "Supported Clients")

## Running Tests

There are some pre-requesites to actually being able to run the unit/integration tests

### On OSX

Edit your /etc/hosts and add the following line:

    127.0.0.1 posttest.localhost

Then ensure that the following packages are installed (boto, s3cmd)

    > pip install boto
    > brew install s3cmd

Run the tests with

    rake test

### In a VM

Install virtualbox and vagrant, and run

    vagrant up

This will bootstrap a development environment in an ubuntu VM. To ssh into the
machine:

    vagrant ssh

To run the tests from inside the VM:

    bundle exec rake test

## More Information

Check out the [wiki](https://github.com/jubos/fake-s3/wiki)
