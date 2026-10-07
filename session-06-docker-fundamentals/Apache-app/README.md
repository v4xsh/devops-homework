# Apache-app - Apache httpd Hello World

**Name:** Vansh Dobhal | **Roll No:** 10099

Part of [Session 6 - Docker Fundamentals](../README.md).

## What it is
`index.html` is copied into Apache's document root `/usr/local/apache2/htdocs/`. The image's default `httpd-foreground` command keeps Apache in the foreground.

Base image(s): `httpd:2.4-alpine`

Files: `Dockerfile`, `index.html`

## Build and run
```bash
cd session-06-docker-fundamentals/Apache-app
docker build -t s06-apache-app:1.0 .
docker run -d --name s06-apache-app -p 8004:80 s06-apache-app:1.0
docker ps --filter name=s06-apache-app
curl -s localhost:8004
```

## Result
The page at `http://localhost:8004` shows:

> Hello World from Apache httpd in Docker - Vansh Dobhal (Roll No. 10099)

![Apache-app build, run and curl](../screenshots/04-Apache-app.png)

Full text log of the same run: [`../outputs/04-Apache-app.txt`](../outputs/04-Apache-app.txt)

## Clean up
```bash
docker rm -f s06-apache-app
```
