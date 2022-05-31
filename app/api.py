import config
import logging
import time
import re
import json
import urllib.parse

import tornado.web
import tornado.gen
import tornado.httpclient

import utils

lg = logging.getLogger('api')
lg.info('start')


class api (tornado.web.RequestHandler):
  
  
  def initialize (self):
    if __debug__: lg.debug('initialize')
    self.app = self.application
    self.db = self.app.settings['db_async']
    #self.s_header_bubble_token = None
    self.s_cm = None
    self.s_params = None
    self.d_params = None
  
  
  @tornado.gen.coroutine
  def options (self, s_cm):
    #print('-- app_api OPTIONS', id(self))
    self.set_headers()
    self.write('OK\n')
  
  @tornado.gen.coroutine
  def get (self, s_cm):
    #print('-- app_api GET', id(self))
    #if __debug__: lg.debug('GET BubbleToken %s' % self.request.headers.get('BubbleToken'))
    #self.s_header_bubble_token = self.request.headers.get('BubbleToken')
    self.s_cm = s_cm
    try:
      self.s_params = urllib.parse.unquote(self.request.query)
      yield self.request_execute(s_cm)
    except Exception as e:
      lg.exception('e_unhandled1\n%s', e)
      yield self.send_answer({'err': 'e_unhandled1', 'msg': 'unhandled app error'})
  
  @tornado.gen.coroutine
  def post (self, s_cm):
    #if __debug__: lg.debug('-- app_api POST ', id(self))
    #if __debug__: lg.debug('files', type(self.request.files), self.request.files)
    #if __debug__: lg.debug('POST BubbleToken %s' % self.request.headers.get('BubbleToken'))
    #self.s_header_bubble_token = self.request.headers.get('BubbleToken')
    self.s_cm = s_cm
    try:
      #if self.request.headers['Content-Type'][:20] == 'multipart/form-data;':
      if self.request.headers.get('Content-Type', '')[:20] == 'multipart/form-data;':
        self.s_params = urllib.parse.unquote(self.get_body_argument('data', ''))
        #if __debug__: lg.debug('self.request.body: ', self.request.body)
        #if __debug__: lg.debug('params: ', self.s_params)
        yield self.request_execute(s_cm)
      else:
        self.s_params = urllib.parse.unquote(self.request.body.decode('utf-8'))
        yield self.request_execute(s_cm)
    except Exception as e:
      lg.exception('e_unhandled2\n%s', e)
      yield self.send_answer({'err': 'e_unhandled2', 'msg': 'unhanled app error'})
  
  def set_headers (self):
    self.set_status(200)
    self.set_header('Pragma', 'no-cache')
    self.set_header('Cache-Control', 'no-cache')
    self.set_header('Content-Type', 'application/json; charset=UTF-8')
    #self.set_header('Access-Control-Allow-Methods', 'GET, POST')  # какие методы могут использоваться для общения с сервером
    #self.set_header('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type')
    #origin = self.request.headers.get('Origin')  # домен сайта (со схемой), с которого происходит запрос, например "http://web.cargo.chat"
    #if true:
    #  self.set_header('Access-Control-Allow-Origin', origin)  # с каких ресурсов могут приходить запросы (может быть только один, и может содержать только одно значение, т.е. список доменов задать нельзя)
    #  self.set_header('Access-Control-Allow-Credentials', 'true')  # разрешается ли передавать Cookie и Authorization заголовки (данные будут передаваться, только если в заголовке Access-Control-Allow-Origin будет явно выставлен конкретный домен)
  
  
  @tornado.gen.coroutine
  def send_answer (self, o):
    #if __debug__: lg.debug(o)
    self.set_headers()
    if __debug__:
      self.write('%s\n' % json.dumps(o, indent=2, ensure_ascii=False, sort_keys=True))
      return
    self.write('%s\n' % json.dumps(o))
  
  
  @tornado.gen.coroutine
  def request_execute (self, s_cm):
    
    # real IP
    #if 'X-Real-Ip' in self.request.headers:
    #  self.request.remote_ip = self.request.headers['X-Real-Ip']
    
    # проверка параметров запроса (валидные варанты: пустая или json строка в виде объекта)
    try:
      self.d_params = json.loads(self.s_params or '{}')
    except Exception as e:
      lg.exception('bad params:\n%s', e)
    if type(self.d_params) is not dict:
      yield self.send_answer({'err': 'e_cmn_bad_params', 'msg': 'unexpected request params'})
      return
    
    #if self.s_header_bubble_token is not None and 'token' not in self.d_params:
    #  self.d_params['token'] = self.s_header_bubble_token
    
    # ping
    if s_cm == 'ping':
      yield self.send_answer({'err': None, 'pong': 1, 'time': int(time.time())})
      return
    
    #s_token = self.request.headers.get('BubbleToken')
    #if s_token is not None and 'token' not in self.d_params:
    #  self.d_params['token'] = s_token
    
    #if __debug__: lg.debug('*** headers %s' % self.request.headers)
    headers = {}
    for h in self.request.headers:
      if h not in headers:
        headers[h] = []
      headers[h].append(self.request.headers[h])
    
    #lg.debug('headers: %s' % json.dumps(headers))
    #{
    #  "Upgrade-Insecure-Requests": ["1"],
    #  "Pragma": ["no-cache"],
    #  "User-Agent": ["Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36 OPR/49.0.2725.64"],
    #  "Connection": ["close"],
    #  "Host": ["bubbles_app_py"],
    #  "Accept-Language": ["en-US,en;q=0.9"],
    #  "Accept-Encoding": ["gzip, deflate, br"],
    #  "Dnt": ["1"],
    #  "X-Real-Ip": ["109.252.19.10"],
    #  "X-Real-Host": ["apps.blissgame.org"],
    #  "Accept": ["text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"],
    #  "Cache-Control": ["no-cache"],
    #  "Cookie": ["__cfduid=db82c3553aea9114f066517394aa649791508411673"]
    #}
    
    if s_cm == 'fb_auth':
      
      if 'access_token' not in self.d_params:
        yield self.send_answer({'err': 'e_fb_auth_invalid_access_token', 'msg': 'parameter "access_token" required'})
        return
      
      #if __debug__: lg.debug('access_token %s' % self.d_params['access_token'])
      
      # curl https://graph.facebook.com/me?fields=id,name -d "access_token=EAAY8xX5Az8YBAFePb5rNxnSEKZAVuyIR4JWehsw4ZCS8ZCJTM2nkn4fYab1QsPnL53sq7hMjjZC2MDkZCUxBt1Xe1VUDhm0CCcQLVBtt9LUs4rUUq0o3qimMjIOYdNcyyBStZBEAQ5D6Cz3oZBKO4o1kvWNomqX8ST58vj1HEQ7tgZDZD"
      # {"id":"1103393989710754","name":"Andrey Yakovlev"}
      
      try:
        fb_req = yield tornado.httpclient.AsyncHTTPClient().fetch(
          'https://graph.facebook.com/me?%s' % urllib.parse.urlencode({
            'access_token': self.d_params['access_token'],
            'fields': 'id,name,email,gender,link,location',
            'pretty': '0',
          }), method = 'GET'
        )
        fb_acc = json.loads(fb_req.body.decode('utf-8'))
        if __debug__: lg.debug('fb_acc %s' % fb_acc)
      except Exception as e:
        lg.exception('fb_req failed:\n%s', e)
        yield self.send_answer({'err': 'e_fb_auth_invalid_access_token', 'msg': 'facebook access_token check: graph fetch failed'})
        return
      
      if not {'id', 'email'}.issubset(fb_acc):
        yield self.send_answer({'err': 'e_fb_auth_invalid_access_token', 'msg': 'facebook access_token check: wrong graph response'})
        return
      
      resp = yield self.db.req('SELECT "public"."_fb_auth"(%s)', [json.dumps(fb_acc)])
      yield self.send_answer(resp)
      return
    
    
    #yield self.send_answer({'err': 'e_unhandled_request', 'msg': 'unhandled request'})
    #return
    #resp = yield self.db.req('SELECT "public"."main"(%s, %s, %s)', [s_cm, json.dumps(self.d_params), self.request.remote_ip])
    resp = yield self.db.req('SELECT "public"."main"(%s, %s, %s)', [s_cm, json.dumps(headers), json.dumps(self.d_params)])
    yield self.send_answer(resp)
    return
    
    


