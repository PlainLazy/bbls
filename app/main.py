#encoding: utf-8

import os
import sys
import signal
import time
import json
import multiprocessing
import threading
import logging
import logging.handlers

import tornado.web
import tornado.gen
import tornado.ioloop

import config
from db_async import db_async
from api import api



def sig_hr (s, frame):
  lg.info('--- bubbles_app_py app sig_hr %s %s', s, frame)
  sys.exit()

signal.signal(signal.SIGINT, sig_hr)
signal.signal(signal.SIGTERM, sig_hr)


##
## logging
##

log_path = '/var/log/bubbles_app_py/'
log_file = 'log'

# logs folder
if not os.path.exists(log_path):
  os.makedirs(log_path)

logging.basicConfig(
    #format = '%(asctime)s.%(msecs)03d %(process)d %(processName)s %(threadName)s %(levelname)s %(name)s %(message)s',
    format = '%(asctime)s.%(msecs)03d %(threadName)s %(levelname)s %(name)s %(message)s',
    datefmt = '%Y.%m.%d %I:%M:%S',
    level  = logging.DEBUG, # logging.INFO |logging.ERROR
)

logfile = '%s%s' % (log_path, log_file)
lh = logging.handlers.TimedRotatingFileHandler(logfile, when='midnight', interval=1, backupCount=5)  # https://docs.python.org/2/library/logging.handlers.html#rotatingfilehandler
#lh.setFormatter(logging.Formatter('%(asctime)s.%(msecs)03d %(process)d %(processName)s %(threadName)s %(levelname)s %(name)s %(message)s', '%Y.%m.%d %I:%M:%S'))
lh.setFormatter(logging.Formatter('%(asctime)s.%(msecs)03d %(threadName)s %(levelname)s %(name)s %(message)s', '%Y.%m.%d %I:%M:%S'))
logging.getLogger().addHandler(lh)


##
## start
##

lg = logging.getLogger('main')
lg.info('--- bubbles_app_py app start')


class now (tornado.web.RequestHandler):
  def get (self):
    self.set_status(200)
    self.set_header('Pragma', 'no-cache')
    self.set_header('Cache-Control', 'no-cache')
    self.set_header('Content-Type', 'application/json; charset=utf-8')
    self.set_header('Access-Control-Allow-Origin', '*')
    self.set_header('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type')
    self.write('now: %s' % time.time())


loop = tornado.ioloop.IOLoop.instance()

# http://www.tornadoweb.org/en/stable/web.html#application-configuration
# используем application.settings как кучу параметров
app = tornado.web.Application([
    (r'/now', now),
    (r'/api/([^//]*).*', api)
  ],
  shotdown = False,
  db_async = db_async(loop),
  debug = False
)

lg.info('listen :%s' % config.app['port'])
app.listen(config.app['port'])



loop.start()


