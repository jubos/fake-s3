## Introduction
FakeS3 is a lightweight server that responds to the same API of Amazon S3.

It is extremely useful for testing of S3 in a sandbox environment without actually making calls to Amazon, which not only requires a network connection, but also costs money with every use.

The goal of Fake S3 is to minimize runtime dependencies and be more of a
development tool to test S3 calls in your code rather than a production server looking to duplicate S3 functionality.

Many commands are supported, including put, get, list, copy, and make bucket.

## Installation

    gem install fakes3

## Running

To run the server, you just specify a root and a port.

    fakes3 -r /mnt/fakes3_root -p 4567

## Connecting to FakeS3

Take a look at the test cases to see client example usage.  For now, FakeS3 is
mainly tested with s3cmd, aws-s3 gem, and right_aws.  There are plenty more
libraries out there, and please do mention if other clients work or not.

Here is a running list of [supported clients](https://github.com/jubos/fake-s3/wiki/Supported-Clients "Supported Clients")

## Contributing

We have a contributor license agreement (CLA) based off of Google and Apache's CLA. If you would feel comfortable contributing to, say, Angular.js, you should feel comfortable with this CLA.

To sign the CLA:

[Click here and fill out the form.](https://docs.google.com/forms/d/e/1FAIpQLSeKKSKNNz5ji1fd5bbu5RaGFbhD45zEaCnAjzBZPpzOaXQsvQ/viewform)

If you're interested, [this blog post](https://julien.ponge.org/blog/in-defense-of-contributor-license-agreements/) discusses why to use a CLA, and even goes over the text of the CLA we based ours on.


## Testing

There are some pre-requesites to actually being able to run the unit/integration tests.

On macOS, edit your /etc/hosts and add the following line:

    127.0.0.1 posttest.localhost

Then ensure that the following packages are installed (boto, s3cmd):

    > pip install boto
    > brew install s3cmd


Start the test server using:

    rake test_server

Finally, in another terminal window run:

    rake test
