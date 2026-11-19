from argparse import ArgumentParser
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Lock
from urllib.request import urlopen
import webbrowser

ROOT = Path(__file__).resolve().parent
SITE = "god-pick-ui"
VERSION = 3
ITEMS = {"cards"}
STATES = {"pending", "approved", "revise", "rejected"}
parser = ArgumentParser()
parser.add_argument("--port", type=int, default=8775)
parser.add_argument("--feedback", type=Path, default=ROOT / "验收反馈.json")
parser.add_argument("--open", action="store_true")
args = parser.parse_args()
url = f"http://127.0.0.1:{args.port}"
lock = Lock()


def current_review():
    if not args.feedback.is_file():
        return {"site": SITE, "version": VERSION, "items": {}}
    return json.loads(args.feedback.read_text(encoding="utf-8"))


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *request):
        super().__init__(*request, directory=str(ROOT))

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def send_json(self, payload):
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/api/review":
            try:
                self.send_json(current_review())
            except (OSError, ValueError):
                self.send_error(500, "Could not read the review file")
            return
        super().do_GET()

    def do_POST(self):
        if self.path != "/api/review":
            self.send_error(404)
            return
        if self.headers.get("Origin") != url or self.headers.get_content_type() != "application/json":
            self.send_error(403)
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            if not 0 < length <= 16000:
                raise ValueError
            data = json.loads(self.rfile.read(length))
            item, status, note = data["id"], data["status"], data["note"]
            if item not in ITEMS or status not in STATES or not isinstance(note, str) or len(note) > 3000:
                raise ValueError
        except (ValueError, KeyError, TypeError):
            self.send_error(400)
            return
        entry = {"status": status, "note": note.strip(), "updatedAt": datetime.now(timezone.utc).isoformat()}
        try:
            with lock:
                report = current_review()
                report["items"][item] = entry
                temp = args.feedback.with_suffix(".tmp")
                temp.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                temp.replace(args.feedback)
        except (OSError, ValueError):
            self.send_error(500, "Could not save the review file")
            return
        self.send_json(entry)


try:
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
except OSError:
    try:
        with urlopen(url + "/api/review", timeout=2) as response:
            report = json.load(response)
            if report.get("site") != SITE or report.get("version") != VERSION:
                raise ValueError
    except (OSError, ValueError):
        raise SystemExit(f"端口 {args.port} 已被占用")
    if args.open:
        webbrowser.open(url)
    raise SystemExit(0)

print(url, flush=True)
if args.open:
    webbrowser.open(url)
with server:
    server.serve_forever()
