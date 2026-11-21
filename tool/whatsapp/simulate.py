"""Sends WhatsApp messages to the whatsapp-webhook function as Meta would
(same JSON, same HMAC signature), and plays Meta's side too: a small local
server hands out the media files and prints the replies Rembo sends back.
With --engines it also answers as an OpenAI-compatible engine (receipt
reading and Whisper transcription), to test the whole channel offline.

  supabase start && supabase db reset         # seed links +212600000003 (Omar)
  supabase functions serve whatsapp-webhook --no-verify-jwt \\
      --env-file tool/whatsapp/local.env
  python3 tool/whatsapp/simulate.py text "Taxi, 45 dirhams, client Atlas"
  python3 tool/whatsapp/simulate.py text oui
  python3 tool/whatsapp/simulate.py image assets/bench/r01.jpg --caption "client Atlas"
  python3 tool/whatsapp/simulate.py audio note.ogg

The function reaches this server at host.docker.internal:8765 (see
local.env). Options: --from 212600000003, --url, --secret, --wait 8.
"""
import argparse
import hashlib
import hmac
import json
import mimetypes
import threading
import time
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

parser = argparse.ArgumentParser()
parser.add_argument("kind", choices=["text", "image", "audio"])
parser.add_argument("value", help="the text, or the path of the file")
parser.add_argument("--caption", default="")
parser.add_argument("--from", dest="sender", default="212600000003")
parser.add_argument("--url", default="http://127.0.0.1:54321/functions/v1/whatsapp-webhook")
parser.add_argument("--secret", default="secret-local-de-test")
parser.add_argument("--port", type=int, default=8765)
parser.add_argument("--wait", type=float, default=8.0, help="seconds to wait for replies")
args = parser.parse_args()

media = None
if args.kind != "text":
    with open(args.value, "rb") as f:
        media = f.read()
    mime = mimetypes.guess_type(args.value)[0] or (
        "audio/ogg" if args.kind == "audio" else "image/jpeg")

replies = []


class FakeMeta(BaseHTTPRequestHandler):
    """Graph API (media, messages) and an OpenAI-compatible engine."""

    def log_message(self, *_):
        pass

    def _json(self, body, status=200):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        host = self.headers.get("host", f"host.docker.internal:{args.port}")
        if self.path == "/media-1":
            return self._json({"url": f"http://{host}/file-1", "mime_type": mime})
        if self.path == "/file-1" and media is not None:
            self.send_response(200)
            self.send_header("content-type", mime)
            self.send_header("content-length", str(len(media)))
            self.end_headers()
            return self.wfile.write(media)
        self._json({"error": "not found"}, 404)

    def do_POST(self):
        length = int(self.headers.get("content-length", 0))
        body = self.rfile.read(length)
        if self.path.endswith("/messages"):
            replies.append(json.loads(body)["text"]["body"])
            return self._json({"messages": [{"id": "wamid.reply"}]})
        if self.path.endswith("/chat/completions"):
            # A receipt engine that reads the bench receipt r01.
            reading = {"readable": True, "supplier": "Café Atlas",
                       "supplier_ice": "001234567000089", "date": "2026-11-10",
                       "total": "240.00", "vat": "21.82", "vat_rate": 10,
                       "currency": "MAD"}
            return self._json({"choices": [{"message": {"content": json.dumps(reading)}}]})
        if self.path.endswith(":generateContent"):
            # Gemini's own API, as used for voice notes.
            return self._json({"candidates": [{"content": {"parts": [
                {"text": "Taxi 30 dirhams client Atlas"}]}}]})
        if self.path.endswith("/audio/transcriptions"):
            return self._json({"text": "Taxi 30 dirhams client Atlas"})
        self._json({"error": "not found"}, 404)


server = ThreadingHTTPServer(("0.0.0.0", args.port), FakeMeta)
threading.Thread(target=server.serve_forever, daemon=True).start()

message = {"from": args.sender, "id": f"wamid.sim.{uuid.uuid4().hex}",
           "timestamp": str(int(time.time())), "type": args.kind}
if args.kind == "text":
    message["text"] = {"body": args.value}
else:
    message[args.kind] = {"id": "media-1", "mime_type": mime}
    if args.caption:
        message[args.kind]["caption"] = args.caption
body = json.dumps({"object": "whatsapp_business_account", "entry": [{"id": "0", "changes": [
    {"field": "messages", "value": {"messaging_product": "whatsapp", "messages": [message]}}]}]}).encode()
signature = "sha256=" + hmac.new(args.secret.encode(), body, hashlib.sha256).hexdigest()
request = urllib.request.Request(args.url, data=body, method="POST", headers={
    "content-type": "application/json", "x-hub-signature-256": signature})
with urllib.request.urlopen(request, timeout=60) as response:
    print(f"webhook: {response.status} {response.read().decode()}")
end = time.time() + args.wait
while not replies and time.time() < end:
    time.sleep(0.2)
for r in replies:
    print("Rembo répond :", r.replace("\n", "\n               "))
if not replies:
    print("(aucune réponse reçue)")
server.shutdown()
