#!/usr/bin/env bash
# Session 7 - Docker images. All commands are executed for real by `snap`.
S=~/devops-homework/session-07-docker-images
cd "$S"
docker rm -f s07-multistage s07-node-single s07-node-multi s07-python-single s07-python-multi \
  s07-java-single s07-java-multi s07-registry >/dev/null 2>&1
rm -rf /tmp/s07-devops-heros /tmp/s07-cache-demo /tmp/s07-ignore-demo

########## Task 1: clone the repo with the multi-stage Dockerfile, build, run ##########
snap 01-task1-clone-repo --dir "$S" <<'EOF'
git clone --depth 1 https://github.com/Nency-Ravaliya/devops-heros.git /tmp/s07-devops-heros 2>&1
cd /tmp/s07-devops-heros/session6-7-docker/multi-stage-dockerfile
ls -la
cat Dockerfile
cat server.js
EOF

snap 02-task1-build-multistage --dir "$S" <<'EOF'
cd /tmp/s07-devops-heros/session6-7-docker/multi-stage-dockerfile
docker build --no-cache --progress=plain -t s07-multistage:1.0 . 2>&1 | grep -E '^#[0-9]+ \[|DONE|CACHED|naming|ERROR' | tail -n 32
docker images s07-multistage
EOF

snap 03-task1-run-and-verify --dir "$S" <<'EOF'
docker run -d --name s07-multistage -p 8080:3000 s07-multistage:1.0
sleep 3
docker ps --filter name=s07-multistage
docker port s07-multistage
curl -s -i localhost:8080
docker logs s07-multistage
EOF

# keep a copy of the instructor's Dockerfile next to the docs (real cp from the clone)
cp /tmp/s07-devops-heros/session6-7-docker/multi-stage-dockerfile/{Dockerfile,server.js,package.json} "$S/task1-multistage/"

########## Task 3: Node.js, Python, Java - single-stage vs multi-stage ##########
n=4
for app in node python java; do
  snap "0${n}-task3-${app}-build" --dir "$S" <<EOF
cd ~/devops-homework/session-07-docker-images/task3-apps/${app}-app
docker build --progress=plain -f Dockerfile.single -t s07-${app}-app:single . 2>&1 | grep -E '^#[0-9]+ \[|naming' | tail -n 12
docker build --progress=plain -t s07-${app}-app:multi . 2>&1 | grep -E '^#[0-9]+ \[|naming' | tail -n 14
docker images s07-${app}-app --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
EOF
  n=$((n+1))
done

snap 07-task3-run-all-six --dir "$S" <<'EOF'
docker run -d --name s07-node-single   -p 8011:3000 s07-node-app:single
docker run -d --name s07-node-multi    -p 8012:3000 s07-node-app:multi
docker run -d --name s07-python-single -p 8013:5000 s07-python-app:single
docker run -d --name s07-python-multi  -p 8014:5000 s07-python-app:multi
docker run -d --name s07-java-single   -p 8015:8080 s07-java-app:single
docker run -d --name s07-java-multi    -p 8016:8080 s07-java-app:multi
sleep 5
docker ps --filter name=s07- --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
for p in 8011 8012 8013 8014 8015 8016; do echo "--- localhost:$p"; curl -s localhost:$p; done
EOF

snap 08-image-size-comparison --dir "$S" <<'EOF'
docker images --filter reference='s07-*' --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | sort
for a in node python java; do s=$(docker image inspect s07-$a-app:single --format '{{.Size}}'); m=$(docker image inspect s07-$a-app:multi --format '{{.Size}}'); echo "$a: single=$((s/1024/1024))MB multi=$((m/1024/1024))MB  saved=$(( (s-m)*100/s ))%"; done
docker exec s07-node-multi whoami
docker exec s07-python-multi whoami
docker exec s07-java-multi whoami
docker exec s07-java-single which mvn javac
docker exec s07-java-multi sh -c 'which mvn javac || echo "no mvn / javac in the runtime image"'
EOF

########## Image concepts ##########
snap 09-docker-history-layers --dir "$S" --max-lines 80 <<'EOF'
docker history s07-node-app:multi --format "table {{.CreatedBy}}\t{{.Size}}" --no-trunc | cut -c1-110
docker history s07-node-app:single --format "table {{.CreatedBy}}\t{{.Size}}" | head -n 8
docker image inspect s07-node-app:multi --format '{{len .RootFS.Layers}} layers'
docker image inspect s07-node-app:single --format '{{len .RootFS.Layers}} layers'
EOF

snap 10-docker-image-inspect --dir "$S" <<'EOF'
docker image inspect s07-python-app:multi --format 'Id={{.Id}}'
docker image inspect s07-python-app:multi --format 'Created={{.Created}} Arch={{.Architecture}} OS={{.Os}}'
docker image inspect s07-python-app:multi | jq '.[0].Config | {User, Env, WorkingDir, ExposedPorts, Cmd}'
docker image inspect s07-python-app:multi | jq '.[0].RootFS.Layers'
EOF

snap 11-build-cache-demo --dir "$S" <<'EOF'
cp -r ~/devops-homework/session-07-docker-images/task3-apps/node-app /tmp/s07-cache-demo && cd /tmp/s07-cache-demo
docker build --progress=plain -t s07-cache-demo:v1 . 2>&1 | grep -E '^#[0-9]+ (\[(deps|stage-1) |CACHED|DONE)'
sed -i 's/Session 7/Session 7 (edited)/' server.js
docker build --progress=plain -t s07-cache-demo:v2 . 2>&1 | grep -E '^#[0-9]+ (\[(deps|stage-1) |CACHED|DONE)'
sed -i 's/express": "^4.21.2"/express": "^4.21.1"/' package.json
docker build --progress=plain -t s07-cache-demo:v3 . 2>&1 | grep -E '^#[0-9]+ (\[(deps|stage-1) |CACHED|DONE)'
EOF

snap 12-dockerignore-demo --dir "$S" <<'EOF'
cp -r ~/devops-homework/session-07-docker-images/task3-apps/node-app /tmp/s07-ignore-demo && cd /tmp/s07-ignore-demo
mkdir -p /tmp/s07-ignore-demo/node_modules/junk && head -c 80M /dev/urandom > /tmp/s07-ignore-demo/node_modules/junk/big.bin && du -sh /tmp/s07-ignore-demo/node_modules
cat .dockerignore
docker build --progress=plain -f Dockerfile.single -t s07-ignore-demo:with-ignore . 2>&1 | grep "transferring context.*done"
mv .dockerignore .dockerignore.off
docker build --progress=plain -f Dockerfile.single -t s07-ignore-demo:without-ignore . 2>&1 | grep "transferring context.*done"
mv .dockerignore.off .dockerignore
docker images s07-ignore-demo --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
docker history s07-ignore-demo:without-ignore --format "{{.CreatedBy}} => {{.Size}}" | grep -E "COPY|npm install"
docker history s07-ignore-demo:with-ignore --format "{{.CreatedBy}} => {{.Size}}" | grep -E "COPY|npm install"
EOF

snap 13-tagging-and-local-registry --dir "$S" <<'EOF'
docker tag s07-node-app:multi s07-node-app:1.0.0
docker tag s07-node-app:multi s07-node-app:latest
docker tag s07-node-app:multi vansh10099/s07-node-app:1.0.0
docker images --filter reference='*s07-node-app*' --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
docker run -d --name s07-registry -p 8020:5000 registry:2
sleep 3
docker tag s07-node-app:1.0.0 localhost:8020/s07-node-app:1.0.0
docker push localhost:8020/s07-node-app:1.0.0 2>&1 | tail -n 4
curl -s localhost:8020/v2/_catalog
curl -s localhost:8020/v2/s07-node-app/tags/list
EOF
