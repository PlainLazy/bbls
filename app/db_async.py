import config
import logging
import momoko
import tornado.gen

lg = logging.getLogger('db_async')
lg.info('start')

class db_async ():
    
    def __init__ (self, loop):
        if __debug__: lg.debug('init %s %s' % (config.database['dbname'], config.database['user']))
        # http://momoko.61924.nl/en/latest/api.html
        self.pool = momoko.Pool(  # Asynchronous conntion pool
            dsn = 'dbname=%s user=%s password=%s host=%s port=%s sslmode=disable' %
                (
                    config.database['dbname'],
                    config.database['user'],
                    config.database['password'],
                    config.database['host'],
                    config.database['port'],
                ),
            size = config.database['pool']['mincon'],  # Minimal number of connections to maintain. size connections will be opened and maintained after calling momoko.Pool.connect()
            max_size = config.database['pool']['maxcon'],  # (int or None) – if not None, the pool size will dynamically grow on demand up to max_size open connections. By default the connections will still be maintained even if when the pool load decreases. See also auto_shrink parameter.
            reconnect_interval = 1000,  # If database server becomes unavailable, the pool will try to reestablish the connection. The attempt frequency is reconnect_interval milliseconds
            ioloop = loop
        )
        
        future = self.pool.connect()
        loop.add_future(future, lambda f: loop.stop())
        loop.start()
        future.result()  # raises exception on connection error
    
    @tornado.gen.coroutine
    def req (self, query, params):
        if __debug__: lg.debug('req %s %s' % (query, params))
        try:
            c = yield self.pool.execute(query, params)
            f = c.fetchone()
            if f is None or len(f) < 1:
                return {'err': 'e_db_no_resp', 'msg': 'DB req failed: empty resp'}
            r = f[0]
            #if type(r) is not dict:
            #    r = {'err': -2000, 'msg': 'unexpected DB resp'}
        except Exception as e:
            #lg.exception('db_async req failed: %s' % e)
            lg.exception('db_async req failed:\n%s' % e)
            # db_async req failed: could not connect to server: Connection refused
            #   Is the server running on host "127.0.0.1" and accepting
            #   TCP/IP connections on port 5432?
            r = {'err': 'e_db_req', 'msg': 'DB req failed'}
        return r
    
    
    