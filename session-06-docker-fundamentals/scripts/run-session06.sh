#!/usr/bin/env bash
# Builds, runs and verifies all six Session 6 Hello World apps.
# Every command below is executed for real by `snap`, which also saves
# screenshots/<name>.png and outputs/<name>.txt.
S=~/devops-homework/session-06-docker-fundamentals
cd "$S"

# start from a clean state (only our own s06- containers)
docker rm -f s06-nodejs-app s06-python-app s06-java-app s06-apache-app s06-react-app s06-nginx-app >/dev/null 2>&1

# app-folder  image/container-name  host-port  container-port
APPS="nodejs-app:s06-nodejs-app:8001:3000
python-app:s06-python-app:8002:5000
java-app:s06-java-app:8003:8080
Apache-app:s06-apache-app:8004:80
React-app:s06-react-app:8005:80
nginx-app:s06-nginx-app:8006:80"

n=1
while IFS=: read -r dir name hport cport; do
  snap "0${n}-${dir}" --dir "$S" <<EOF
cd ~/devops-homework/session-06-docker-fundamentals/${dir}
ls -A
docker build --progress=plain -t ${name}:1.0 . 2>&1 | tail -n 20
docker run -d --name ${name} -p ${hport}:${cport} ${name}:1.0
sleep 4
docker ps --filter name=${name} --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
curl -s localhost:${hport}
EOF
  n=$((n+1))
done <<< "$APPS"

snap 07-all-containers-and-images --dir "$S" <<'EOF'
docker ps --filter name=s06- --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
docker images --filter reference='s06-*' --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
for p in 8001 8002 8003 8004 8005 8006; do echo "--- localhost:$p"; curl -s localhost:$p | grep -o 'Hello World from [A-Za-z.() ]* in Docker[^<]*' | head -n 1; done
EOF

snap 08-react-page-source --dir "$S" <<'EOF'
curl -s localhost:8005
curl -s localhost:8005/$(curl -s localhost:8005 | grep -o 'assets/index-[^"]*\.js') | grep -o 'Hello World from React[^"]*' | head -n 1
docker logs s06-nodejs-app
docker logs s06-python-app 2>&1 | tail -n 5
docker logs s06-java-app
EOF
