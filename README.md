![Fake S3](static/logo.png "Fake S3")

## Introduction

Fake S3 is a lightweight server that responds to the same API of Amazon S3.

It is extremely useful for testing of S3 in a sandbox environment without actually making calls to Amazon, which not only requires a network connection, but also costs money with every use.

The goal of Fake S3 is to minimize runtime dependencies and be more of a
development tool to test S3 calls in your code rather than a production server looking to duplicate S3 functionality.

Many commands are supported, including put, get, list, copy, and make bucket.

## Installation

    gem install fakes3

## Running

To run the server, you just specify a root and a port.

    fakes3 -r /mnt/fakes3_root -p 4567

## Licensing

As of the latest version, we are licensing with Super Source. To get a license, visit:

https://supso.org/projects/fake-s3 

Depending on your company's size, the license may be free. It is also free for individuals.

## Connecting to Fake S3

Take a look at the test cases to see client example usage.  For now, Fake S3 is
mainly tested with s3cmd, aws-s3 gem, and right_aws.  There are plenty more
libraries out there, and please do mention if other clients work or not.

Here is a running list of [supported clients](https://github.com/jubos/fake-s3/wiki/Supported-Clients "Supported Clients")

## Contributing

Contributions in the form of pull requests, bug reports, documentation, or anything else are welcome! Please read the CONTRIBUTING.md file for more info: [CONTRIBUTING.md](https://github.com/jubos/fake-s3/blob/master/CONTRIBUTING.md)
