## Contributing to Fake S3

Contributions in the form of pull requests, bug reports, documentation, or anything else are welcome! We do have a few small rules to follow:

- Ensure tests pass before making a pull request. (You can read the Testing section below for how to set up your development environment and run tests)

- Please use a coding style similar to the rest of the file(s) you change. This isn't a hard rule but if it's too different, it will stand out.

- Unless your contributions fall under the trivial exemption policy (below), contributors must sign our Contributor License Agreement (CLA) to be eligible to contribute. Read more in section is below.


## Testing

There are some prerequisites to actually being able to run the unit/integration tests.

On macOS, edit your /etc/hosts and add the following line:

    127.0.0.1 posttest.localhost

Then ensure that the following packages are installed (boto, s3cmd):

    > pip install boto
    > brew install s3cmd


Start the test server using:

    rake test_server

Finally, in another terminal window run:

    rake test


## Signing the Contributor License agreement

We have a contributor license agreement (CLA) based off of Google and Apache's CLA. If you would feel comfortable contributing to, say, Angular.js, you should feel comfortable with this CLA.

To sign the CLA:

[Click here and fill out the form.](https://docs.google.com/forms/d/e/1FAIpQLSeKKSKNNz5ji1fd5bbu5RaGFbhD45zEaCnAjzBZPpzOaXQsvQ/viewform)

If you're interested, [this blog post](https://julien.ponge.org/blog/in-defense-of-contributor-license-agreements/) discusses why to use a CLA, and even goes over the text of the CLA we based ours on.


## Trivial Exemption Policy

The Trivial Exemption Policy exempts contributions that would not be sufficiently robust or creative to enjoy copyright protection, and therefore do not need to sign the CLA. This would generally be changes that don't involve much creativity.

Contributions considered trivial are generally fewer than 10 lines of actual code. (It may be longer than 10 lines, for example these would often be larger: blank lines, changes in indentation, formatting, simple comments, logging messages, changes to metadata like Gemfiles or gitignore, reordering, breaking or combining files, renaming files, or other unoriginal changes)
