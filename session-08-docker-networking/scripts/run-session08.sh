#!/usr/bin/env bash
# Session 8 - Docker networking & volumes. All commands are executed for real by `snap`.
S=~/devops-homework/session-08-docker-networking
cd "$S"
export MYSQL_PWD='Vansh@10099'   # demo-only root password for the throwaway MySQL containers

# clean state (only our own s08- objects)
docker rm -f s08-frontend s08-backend s08-database s08-apache-host s08-bind-nginx s08-voldb s08-voldb-new >/dev/null 2>&1
docker network rm s08-frontend-net s08-backend-net s08-db-net >/dev/null 2>&1
docker volume rm s08-mysql-data >/dev/null 2>&1
cp 03-bind-mount/index.original.html 03-bind-mount/site/index.html

########## Task 1: 3 containers, 3 networks, backend on 2 networks ##########
snap 01-task1-create-networks --dir "$S" <<'EOF'
docker network create --driver bridge s08-frontend-net
docker network create --driver bridge s08-backend-net
docker network create --driver bridge s08-db-net
docker network ls --filter name=s08-
EOF

snap 02-task1-run-containers --dir "$S" <<'EOF'
cd ~/devops-homework/session-08-docker-networking/01-multi-network
docker run -d --name s08-frontend --network s08-frontend-net -p 8021:80 -v "$(readlink -f frontend)":/usr/share/nginx/html:ro nginx:alpine
docker run -d --name s08-backend --network s08-frontend-net -v "$(readlink -f backend)":/usr/share/nginx/html:ro nginx:alpine
docker network connect s08-db-net s08-backend
docker run -d --name s08-database --network s08-db-net -e MYSQL_ROOT_PASSWORD="$MYSQL_PWD" -e MYSQL_DATABASE=appdb mysql:8
until docker logs s08-database 2>&1 | grep -q 'ready for connections.*port: 3306'; do sleep 3; done; echo "mysql is ready"
docker ps --filter name=s08- --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Networks}}"
for c in s08-frontend s08-backend s08-database; do echo "$c -> $(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}={{$v.IPAddress}} {{end}}' $c)"; done
EOF

snap 03-task1-connectivity-tests --dir "$S" <<'EOF'
echo "=== 1) frontend -> backend (both on s08-frontend-net) : should WORK"
docker exec s08-frontend ping -c 2 s08-backend
docker exec s08-frontend wget -qO- http://s08-backend
echo "=== 2) backend -> database (both on s08-db-net) : should WORK"
docker exec s08-backend ping -c 2 s08-database
docker exec s08-backend nc -zv -w 3 s08-database 3306
echo "=== 3) frontend -> database (no common network) : should FAIL"
docker exec s08-frontend ping -c 2 -W 2 s08-database
docker exec s08-frontend nc -zv -w 3 s08-database 3306
echo "=== 4) a container on s08-backend-net cannot reach either tier"
docker run --rm --network s08-backend-net alpine:3.20 ping -c 2 -W 2 s08-backend
EOF

snap 04-task1-db-query-and-ip-test --dir "$S" <<'EOF'
docker run --rm --network s08-db-net -e MYSQL_PWD mysql:8 mysql -h s08-database -uroot -e "SELECT @@hostname AS db_host, VERSION() AS version; SHOW DATABASES LIKE 'appdb';"
DBIP=$(docker inspect -f '{{(index .NetworkSettings.Networks "s08-db-net").IPAddress}}' s08-database); echo "database IP on s08-db-net = $DBIP"
docker exec s08-frontend ping -c 2 -W 2 $DBIP
curl -s localhost:8021
EOF

snap 05-task1-network-inspect --dir "$S" --max-lines 90 <<'EOF'
docker network inspect s08-frontend-net --format '{{.Name}}  driver={{.Driver}}  subnet={{range .IPAM.Config}}{{.Subnet}}{{end}}  gateway={{range .IPAM.Config}}{{.Gateway}}{{end}}'
docker network inspect s08-frontend-net | jq '.[0].Containers | map({Name, IPv4Address})'
docker network inspect s08-db-net --format '{{.Name}}  driver={{.Driver}}  subnet={{range .IPAM.Config}}{{.Subnet}}{{end}}'
docker network inspect s08-db-net | jq '.[0].Containers | map({Name, IPv4Address})'
docker network inspect s08-backend-net | jq '.[0] | {Name, Driver, Containers}'
docker inspect s08-backend | jq '.[0].NetworkSettings.Networks | keys'
EOF

########## Task 2: Apache with --network host on port 80 ##########
snap 06-task2-apache-host-network --dir "$S" <<'EOF'
sudo ss -ltnp 'sport = :80' ; echo "(nothing is listening on :80 before the test)"
docker run -d --name s08-apache-host --network host ubuntu/apache2:latest
sleep 3
docker ps --filter name=s08-apache-host --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Networks}}"
sudo ss -ltnp 'sport = :80'
curl -s -I localhost:80 | head -n 4
curl -s localhost:80 | grep -o '<title>.*</title>'
docker inspect s08-apache-host -f 'NetworkMode={{.HostConfig.NetworkMode}}  PortBindings={{.HostConfig.PortBindings}}'
docker rm -f s08-apache-host
curl -s -o /dev/null -w "after stop -> curl exit code %{exitcode}, http code %{http_code}\n" localhost:80
EOF

########## Task 3: bind mount + live change ##########
snap 07-task3-bind-mount --dir "$S" <<'EOF'
cd ~/devops-homework/session-08-docker-networking/03-bind-mount
cat site/index.html
docker run -d --name s08-bind-nginx -p 8023:80 -v "$(readlink -f site)":/usr/share/nginx/html nginx:alpine
sleep 2
curl -s localhost:8023
docker inspect s08-bind-nginx | jq '.[0].Mounts'
docker inspect -f 'StartedAt={{.State.StartedAt}} RestartCount={{.RestartCount}}' s08-bind-nginx
EOF

snap 08-task3-modify-without-restart --dir "$S" <<'EOF'
cd ~/devops-homework/session-08-docker-networking/03-bind-mount
sleep 5
sed -i 's#<h1>Hello students</h1>#<h1>Hello students - UPDATED on the host without restarting the container!</h1>#' site/index.html
cat site/index.html
curl -s localhost:8023
docker exec s08-bind-nginx cat /usr/share/nginx/html/index.html
docker inspect -f 'StartedAt={{.State.StartedAt}} RestartCount={{.RestartCount}}' s08-bind-nginx
docker ps --filter name=s08-bind-nginx --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
EOF

########## Task 4: overlay network demo (single-node swarm) ##########
snap 09-task4-overlay-swarm --dir "$S" --max-lines 90 <<'EOF'
docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
docker node ls
docker network create -d overlay --attachable s08-overlay-net
docker network ls --filter driver=overlay
docker service create --name s08-web --network s08-overlay-net --replicas 2 -p 8024:80 nginx:alpine >/dev/null
until [ "$(docker service ls --filter name=s08-web --format '{{.Replicas}}')" = "2/2" ]; do sleep 2; done
docker service ls
docker service ps s08-web --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"
EOF

snap 10-task4-overlay-test --dir "$S" --max-lines 90 <<'EOF'
docker run --rm --network s08-overlay-net alpine:3.20 nslookup tasks.s08-web
docker run --rm --network s08-overlay-net alpine:3.20 sh -c 'wget -qO- http://s08-web | grep -o "<title>.*</title>"'
curl -s localhost:8024 | grep -o '<title>.*</title>'
docker network inspect s08-overlay-net | jq '.[0] | {Name, Driver, Scope, Attachable, Subnet: .IPAM.Config[0].Subnet, Options}'
docker network inspect ingress | jq '.[0] | {Name, Driver, Scope, Ingress, Options}'
sudo ss -lntu | grep -E ':(2377|7946|4789)\b'
EOF

snap 11-task4-overlay-cleanup --dir "$S" <<'EOF'
docker service rm s08-web
sleep 5
docker network rm s08-overlay-net
docker swarm leave --force
docker info --format 'Swarm: {{.Swarm.LocalNodeState}}'
EOF

########## Volumes: named volume persistence + tmpfs ##########
snap 12-volumes-named-volume-persistence --dir "$S" <<'EOF'
docker volume create s08-mysql-data
docker run -d --name s08-voldb -e MYSQL_ROOT_PASSWORD="$MYSQL_PWD" -v s08-mysql-data:/var/lib/mysql mysql:8
until docker logs s08-voldb 2>&1 | grep -q 'ready for connections.*port: 3306'; do sleep 3; done; echo "mysql is ready"
docker exec -e MYSQL_PWD s08-voldb mysql -uroot -e "CREATE DATABASE school; CREATE TABLE school.students(id INT PRIMARY KEY, name VARCHAR(50), roll INT); INSERT INTO school.students VALUES (1,'Vansh Dobhal',10099);"
docker exec -e MYSQL_PWD s08-voldb mysql -uroot -e "SELECT * FROM school.students;"
docker rm -f s08-voldb
docker ps -a --filter name=s08-voldb --format '{{.Names}}' | wc -l
docker run -d --name s08-voldb-new -e MYSQL_ROOT_PASSWORD="$MYSQL_PWD" -v s08-mysql-data:/var/lib/mysql mysql:8
until docker logs s08-voldb-new 2>&1 | grep -q 'ready for connections.*port: 3306'; do sleep 3; done; echo "new mysql container is ready"
docker exec -e MYSQL_PWD s08-voldb-new mysql -uroot -e "SELECT * FROM school.students;"
EOF

snap 13-volumes-inspect-and-tmpfs --dir "$S" <<'EOF'
docker volume ls --filter name=s08-
docker volume inspect s08-mysql-data
sudo ls /var/lib/docker/volumes/s08-mysql-data/_data | head -n 12
docker run --rm --tmpfs /scratch:size=16m alpine:3.20 sh -c 'echo temp > /scratch/f && df -h /scratch && mount | grep /scratch'
docker run --rm -v s08-mysql-data:/data:ro alpine:3.20 ls /data/school
EOF
