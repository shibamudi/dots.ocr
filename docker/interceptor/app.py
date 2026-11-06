"""Flask interceptor for dots.ocr frontend deployment.

Catches requests to ``/manifest.json`` and ``/ocr/config`` (routed by Traefik)
and returns an empty JSON body. Used to suppress browser/config probes that
the Gradio frontend would otherwise 404 on.

Extracted from the inline ``sh -c`` command previously living in
``docker-compose.origin.yaml``.
"""

import os

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/", defaults={"path": ""}, methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"])
@app.route("/<path:path>", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"])
def catch_all(path):
    return jsonify({})


if __name__ == "__main__":
    port = int(os.environ.get("INTERCEPTOR_PORT", "8000"))
    app.run(host="0.0.0.0", port=port)
