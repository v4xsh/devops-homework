# java-app - Java (JDK HttpServer, Maven multi-stage) Hello World

**Name:** Vansh Dobhal | **Roll No:** 10099

Part of [Session 6 - Docker Fundamentals](../README.md).

## What it is
`HelloServer.java` uses the JDK's built-in `com.sun.net.httpserver.HttpServer` (no framework). `pom.xml` builds `target/hello-java.jar` with the main class in the manifest. The Dockerfile is multi-stage: Maven + JDK compile the jar, only the jar is copied into a JRE-only Alpine image.

Base image(s): `maven:3.9-eclipse-temurin-17 -> eclipse-temurin:17-jre-alpine`

Files: `.dockerignore`, `Dockerfile`, `pom.xml`, `src`

## Build and run
```bash
cd session-06-docker-fundamentals/java-app
docker build -t s06-java-app:1.0 .
docker run -d --name s06-java-app -p 8003:8080 s06-java-app:1.0
docker ps --filter name=s06-java-app
curl -s localhost:8003
```

## Result
The page at `http://localhost:8003` shows:

> Hello World from Java in Docker - Vansh Dobhal (Roll No. 10099)

![java-app build, run and curl](../screenshots/03-java-app.png)

Full text log of the same run: [`../outputs/03-java-app.txt`](../outputs/03-java-app.txt)

## Clean up
```bash
docker rm -f s06-java-app
```
