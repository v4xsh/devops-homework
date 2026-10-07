# tools/

Helper scripts I used to capture terminal evidence for every session.

| File | Purpose |
|------|---------|
| `snap.sh` | Runs a list of commands **for real** (one per line from stdin, in a single shell so `cd`/variables persist) and saves both a PNG screenshot and a plain-text log of the run. |
| `termshot.py` | Renders the captured session (prompt, command, output) as a macOS-style terminal window PNG. Title bar shows my name, roll number and the capture time. |

## Usage

```bash
sudo ln -sf ~/devops-homework/tools/snap.sh /usr/local/bin/snap   # once

cd ~/devops-homework/session-09-kubernetes-fundamentals
snap 01-cluster-status <<'EOF'
minikube status
kubectl get nodes -o wide
EOF
# -> screenshots/01-cluster-status.png  +  outputs/01-cluster-status.txt
```

Options: `--dir <folder>` (where to save), `--max-lines N` (long output is shortened in the middle of the PNG; the `.txt` always keeps the full output), `--cols N`.

## Environment the screenshots were taken on

| Item | Value |
|------|-------|
| Host | Windows 11 laptop `Vansh-G15` |
| Linux | Ubuntu 24.04 LTS on WSL2 (kernel 6.6 microsoft-standard-WSL2) |
| Container runtime | Docker Engine (docker-ce) |
| Kubernetes | minikube (docker driver), addons: ingress, metrics-server, storage-provisioner |
| Other | kubectl, Helm 3, Terraform, Trivy, Gitleaks, act, Node 20, Python 3.12, OpenJDK 17 + Maven |
