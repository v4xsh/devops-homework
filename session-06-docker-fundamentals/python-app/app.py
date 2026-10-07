from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello():
    return "<h1>Hello World from Python (Flask) in Docker - Vansh Dobhal (Roll No. 10099)</h1>\n"


@app.route("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    # 0.0.0.0 so the server is reachable from outside the container
    app.run(host="0.0.0.0", port=5000)
