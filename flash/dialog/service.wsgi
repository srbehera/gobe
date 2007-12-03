#!/usr/bin/python

from pyamf.gateway.wsgi import WSGIGateway
import pyamf.amf0
import sys

def bagwrap(fn):
    def newfn(*args, **kwargs):
        return pyamf.Bag(fn(*args, **kwargs))
    return newfn

@bagwrap
def save(*args):
    """called when user clicks [save] in the flash annotation swf. saves changes to db.
    args[0] looks like {'keywords':['EXON_NOT_CALLED',...], 'annos':['BIGFOOT',...]}
    """
    data = args[0]
    print >>sys.stderr, data, type(data)
    return data

@bagwrap
def load(genespace_id):
    ret = {'notes':'SENT FROM SERVER','annos':[0, 3],'keywords':[2,1]}
    print >>sys.stderr, ret, type(ret)
    return ret
  

application = WSGIGateway({
    'save': save
    ,'load': load
    })


