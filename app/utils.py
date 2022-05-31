import re
import json
import hashlib
import random
import logging

class json_encoder (json.JSONEncoder):
  def default(self, o):
    if type(o) is bytes:
      return o.decode('utf-8')
    return json.JSONEncoder.default(self, o)

def o2j (src):
  if type(src) is dict or type(src) is list:
    return json.dumps(src, indent=2, ensure_ascii=False, cls=json_encoder)
  logging.warning('utils.o2j failed with invalid parameter: type=%s content=%s' % (type(src), src))
  return ''

def j2o (src):
  try:
    o = json.loads(src)
  except Exception as e:
    lg.exception('utils.j2o failed: %s', e)
    return None
  return o

def md5 (txt):
  return hashlib.new('md5', txt.encode('utf8')).hexdigest()