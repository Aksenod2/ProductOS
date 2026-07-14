import http.server
import os
import sys
import time

PORT = 8765
DIR = os.path.dirname(os.path.abspath(__file__))

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIR, **kwargs)
    def log_message(self, format, *args):
        pass

server = http.server.HTTPServer(('127.0.0.1', PORT), Handler)
print(f'Схемы: http://127.0.0.1:{PORT}/')
print(f'Открой в браузере: http://127.0.0.1:{PORT}/')
sys.stdout.flush()
server.serve_forever()
