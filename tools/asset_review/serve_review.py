from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
import argparse,webbrowser,urllib.request
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(); parser.add_argument('--port',type=int,default=8768); parser.add_argument('--open-browser',action='store_true'); args=parser.parse_args()
url=f'http://127.0.0.1:{args.port}/docs/%E8%8A%AC%E5%B8%83%E5%B0%94%E4%B9%8B%E5%86%AC%E6%A8%A1%E5%9E%8B%E6%B8%85%E5%8D%95/index.html'
try: server=ThreadingHTTPServer(('127.0.0.1',args.port),partial(SimpleHTTPRequestHandler,directory=str(ROOT)))
except OSError:
    try:
        with urllib.request.urlopen(url,timeout=2) as response: existing=response.read(200000)
        assert b'quality-models.js' in existing and b'model3d' in existing
    except Exception:
        raise SystemExit('Review port is occupied by another service; choose --port with a different value.')
    if args.open_browser: webbrowser.open(url)
    print('Existing model review server is ready: '+url,flush=True)
    raise SystemExit(0)
if args.open_browser: webbrowser.open(url)
print('MODEL_REVIEW_URL '+url,flush=True)
server.serve_forever()
