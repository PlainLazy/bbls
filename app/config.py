import os
import sys

app = dict(
  port = 58000
)

database = dict(
  pool = dict(mincon = 1, maxcon = 8),
  dbname = os.environ.get('DB_NAME', 'bbldb'),
  user = os.environ.get('DB_USER', 'bbluser'),
  password = os.environ.get('DB_PASS', '654987'),  # docker
  host = 'db',
  port = 5432
)


if '-dev' in sys.argv:
  app['port'] = 58001