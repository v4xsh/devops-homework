"""DELIBERATELY INSECURE training file - used only to show what SAST tools detect.

It is never imported by the application, is excluded from the Docker image (.dockerignore)
and from the pipeline's SAST target (the pipeline scans app/ only). Each function shows one
classic weakness; the comment names the Bandit / Semgrep rule that catches it.
"""
import hashlib
import pickle
import sqlite3
import subprocess

import requests
import yaml
from flask import Flask

demo = Flask(__name__)


def ping(host):
    # Bandit B602 / semgrep subprocess-shell-true  -> command injection (host="x; rm -rf /")
    return subprocess.call("ping -c 1 " + host, shell=True)


def calc(expression):
    # Bandit B307 / semgrep eval-or-exec  -> arbitrary code execution
    return eval(expression)


def load_config(text):
    # Bandit B506 / semgrep unsafe-yaml-load  -> object construction from YAML
    return yaml.load(text, Loader=yaml.Loader)


def restore_session(blob):
    # Bandit B301 / semgrep pickle-loads  -> code execution on untrusted bytes
    return pickle.loads(blob)


def hash_password(password):
    # Bandit B324 / semgrep weak-hash-md5-sha1  -> broken hash for passwords
    return hashlib.md5(password.encode()).hexdigest()


def find_user(name):
    # Bandit B608 / semgrep sql-string-format  -> SQL injection (name="' OR 1=1 --")
    cur = sqlite3.connect(":memory:").cursor()
    cur.execute(f"SELECT * FROM users WHERE name = '{name}'")
    return cur.fetchall()


def fetch(url):
    # Bandit B501 / semgrep requests-verify-false  -> man-in-the-middle
    return requests.get(url, verify=False, timeout=5)


if __name__ == "__main__":
    # Bandit B201 + B104 / semgrep flask-debug-enabled  -> Werkzeug debugger exposed on all interfaces
    demo.run(host="0.0.0.0", debug=True)
