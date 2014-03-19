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

## Install test dependencies

s3cmd (not the gem)

    echo "Installing S3cmd..."
    wget -O- -q http://s3tools.org/repo/deb-all/stable/s3tools.key | sudo apt-key add -
    sudo wget -O/etc/apt/sources.list.d/s3tools.list http://s3tools.org/repo/deb-all/stable/s3tools.list
    sudo apt-get update && sudo apt-get install s3cmd
    echo "Done"

python boto

    sudo apt-get install python-boto

add the following line to /etc/hosts

    127.0.1.1   posttest.localhost

## Backdoor development REST api

This REST api is for simulating lifecycle events on the S3 objects.

List all the S3 objects with their bucket, name, location(storage class), and 'state'

    GET /ADMIN_CONTROL

Move object to glacier storage class

    PUT /ADMIN_CONTROL/TO_GLACIER/<full_object_name>

Move object to standard storage class

    PUT /ADMIN_CONTROL/TO_STANDARD/<full_object_name>

Move object to 'restoring from glacier' status

    PUT /ADMIN_CONTROL/TO_RESTORING/<full_object_name>

Move object to 'restored' status

    PUT /ADMIN_CONTROL/TO_RESTORED/<full_object_name>

Move object to 'restored but restored copy is expired' status

    PUT /ADMIN_CONTROL/TO_RESTORED_EXPIRED/<full_object_name>


## Running Tests

Start the test server using

    rake test_server

Then in another terminal window run

    rake test

It is a TODO to get this to be just one command

## More Information

Check out the [wiki](https://github.com/jubos/fake-s3/wiki)
