#!/usr/bin/python

# -*- coding: utf-8 -*-
# fakes3cmd.py -- an s3cmd-like script that accepts a custom host and portname
from __future__ import print_function
import re
import os
from optparse import OptionParser

try:
    from boto.s3.connection import S3Connection, OrdinaryCallingFormat
    from boto.s3.key import Key
except ImportError:
    raise Exception('You must install the boto package for python')


class FakeS3Cmd(object):
    COMMANDS = ['mb', 'rb', 'put', ]
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.conn = None
        self._connect()

    def _connect(self):
        print('Connecting: %s:%s' % (self.host, self.port))
        self.conn = S3Connection(is_secure=False,
                                 calling_format=OrdinaryCallingFormat(),
                                 aws_access_key_id='',
                                 aws_secret_access_key='',
                                 port=self.port, host=self.host)


    @staticmethod
    def _parse_uri(path):
        match = re.match(r's3://([^/]+)(?:/(.*))?', path, re.I)
        ## (bucket, key)
        return match.groups()

    def mb(self, path, *args):
        if not self.conn:
            self._connect()

        bucket, _ = self._parse_uri(path)
        self.conn.create_bucket(bucket)
        print('made bucket: [%s]' % bucket)

    def rb(self, path, *args):
        if not self.conn:
            self._connect()

        bucket, _ = self._parse_uri(path)
        self.conn.delete_bucket(bucket)
        print('removed bucket: [%s]' % bucket)

    def put(self, *args):
        if not self.conn:
            self._connect()

        args = list(args)
        path = args.pop()
        bucket_name, prefix = self._parse_uri(path)
        bucket = self.conn.create_bucket(bucket_name)
        for src_file in args:
            key = Key(bucket)
            key.key = os.path.join(prefix, os.path.basename(src_file))
            key.set_contents_from_filename(src_file)
            print('stored: [%s]' % key.key)


if __name__ == "__main__":
    # check for options. TODO: This requires a more verbose help message
    # to explain how the positional arguments work.
    parser = OptionParser()
    parser.add_option("-t", "--host", type="string", default='localhost')
    parser.add_option("-p", "--port", type='int', default=80)
    o, args = parser.parse_args()

    if len(args) < 2:
        raise ValueError('you must minimally supply a desired command and s3 uri')

    cmd = args.pop(0)

    if cmd not in FakeS3Cmd.COMMANDS:
        raise ValueError('%s is not a valid command' % cmd)

    fs3 = FakeS3Cmd(o.host, o.port)
    handler = getattr(fs3, cmd)
    handler(*args)
