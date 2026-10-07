import socket

from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello():
    return (
        "<h1>Hello World from Python - Session 7 - Vansh Dobhal (10099)</h1>"
        f"<p>container: {socket.gethostname()}</p>\n"
    )
