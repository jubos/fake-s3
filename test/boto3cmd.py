#!/usr/bin/python
# -*- coding: utf-8 -*-
# fakes3cmd.py -- an s3cmd-like script that accepts a custom host and portname
import re
import os
from optparse import OptionParser

try:
    from boto3 import resource
    from botocore.utils import fix_s3_host 
except ImportError:
    raise Exception('You must install the boto3 package for python')


class FakeS3Cmd(object):
    COMMANDS = ['mb', 'rb', 'put', ]
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.conn = None
        self._connect()

    def _connect(self):
        print 'Connecting: %s:%s' % (self.host, self.port)
        self.conn = resource('s3',
                             aws_access_key_id='',
                             aws_secret_access_key='',
                             endpoint_url='%s:%s' % (self.host, self.port) )
        self.conn.meta.client.meta.events.unregister('before-sign.s3', fix_s3_host)


    @staticmethod
    def _parse_uri(path):
        match = re.match(r's3://([^/]+)(?:/(.*))?', path, re.I)
        ## (bucket, key)
        return match.groups()

    def mb(self, path, *args):
        if not self.conn:
            self._connect()

        bucket, _ = self._parse_uri(path)
        self.conn.create_bucket(Bucket=bucket)
        print 'made bucket: [%s]' % bucket

    def rb(self, path, *args):
        if not self.conn:
            self._connect()

        bucket, _ = self._parse_uri(path)
        self.conn.delete_bucket(bucket)
        print 'removed bucket: [%s]' % bucket

    def put(self, *args):
        if not self.conn:
            self._connect()

        args = list(args)
        path = args.pop()
        bucket_name, prefix = self._parse_uri(path)
        self.conn.create_bucket(Bucket=bucket_name)
        bucket = self.conn.Bucket(name=bucket_name)
        for src_file in args:
            key = bucket.Object(os.path.basename(src_file))
            key.upload(src_file)
            print 'stored: [%s]' % key.key


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
