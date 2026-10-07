**Name:** Vansh Dobhal | **Roll No:** 10099

# Session 15: Helm – the package manager for Kubernetes

All work was done on a local **minikube** cluster (Kubernetes v1.37.0, docker driver, inside WSL Ubuntu 24.04) with **Helm v3.16.2**. Every screenshot is a real terminal run captured with the `snap` tool: the PNG is in `screenshots/` and the exact text of the same run is in `outputs/`. Nothing was typed in by hand.

| Part | Folder | Namespace | Chart |
|------|--------|-----------|-------|
| Task 1: Helm Commands | [`01-helm-commands/`](01-helm-commands/README.md) | `s15` | `webapp` (made with `helm create`) |
| Task 2: Helm Rollback workflow | [`02-helm-rollback/`](02-helm-rollback/README.md) | `s15-rollback` | `rollback-demo` (own chart) |
| Task 3: Helm Mini Project | [`mini-project/`](mini-project/README.md) | `s15-mini` | `notes-chart` (own chart) |

---

## Core concepts (my notes)

| Term | Meaning | Analogy |
|------|---------|---------|
| **Chart** | A folder (or `.tgz`) of templated Kubernetes manifests plus metadata and default values | recipe |
| **Values** | Configuration fed into the templates (`values.yaml`, `-f file`, `--set`) | ingredients |
| **Release** | One installed instance of a chart in a namespace, with a name (`notes-dev`, `notes-prod`) | the cooked meal |
| **Revision** | A numbered version of a release. Each install, upgrade or rollback adds one. Stored as Secret `sh.helm.release.v1.<rel>.v<N>`. | saved snapshot |
| **Repository** | An HTTP server with an `index.yaml` listing packaged charts (e.g. bitnami, prometheus-community) | app store |

**Why Helm instead of plain `kubectl apply`:** one chart serves all environments (only the values file differs), installs and upgrades are versioned with `history` and one-command `rollback`, related objects are grouped and removed together with `uninstall`, and charts can be shared and versioned through repositories.

**Helm 2 vs Helm 3:** Helm 3 has no in-cluster Tiller. It is a client-only tool that uses your kubeconfig RBAC and stores release state as Secrets in the release's namespace (seen in [Task 1 – install](01-helm-commands/screenshots/05-install.png): `sh.helm.release.v1.web1.v1`).

---

## Task 1: Helm Commands

Full write-up: **[01-helm-commands/README.md](01-helm-commands/README.md)** (15 screenshots).

Covered, each one executed, explained and captured: `helm create`, `lint`, `template`, `show chart/values`, `install --dry-run`, `install`, `list`, `status`, `get values/manifest/notes/hooks/metadata/all`, `upgrade` (`--set`, `--install`, `--reuse-values`), `history`, `rollback`, `test`, `repo add/list/update/remove` (bitnami, prometheus-community), `search repo` and `search hub`, `package`, `pull`, `uninstall`.

![helm create](01-helm-commands/screenshots/01-version-create.png)
![history and rollback](01-helm-commands/screenshots/10-history-rollback.png)
![search repo and hub](01-helm-commands/screenshots/13-search-repo-hub.png)

## Task 2: Helm Rollback

Full write-up: **[02-helm-rollback/README.md](02-helm-rollback/README.md)** (13 screenshots).

Install (v1: nginx 1.25, 1 replica, blue page) → Upgrade (v2: nginx 1.26, 2 replicas, green) → Verify → Upgrade again (v3: nginx 1.27, 3 replicas, red, resource limits) → Verify → **Rollback to 2** → Verify, then `--atomic` with a broken tag, which rolled back automatically. Each step was verified with the deployment image/replicas (`-o jsonpath`), the page served over HTTP and the nginx `Server:` header (both fetched with `wget` from a client pod), and `helm history`.

![verify rev 3](02-helm-rollback/screenshots/07-verify-rev3.png)
![rollback to 2](02-helm-rollback/screenshots/09-rollback-to-rev2.png)
![verify after rollback](02-helm-rollback/screenshots/10-verify-after-rollback.png)
![atomic auto rollback](02-helm-rollback/screenshots/11-atomic-auto-rollback.png)

## Task 3: Helm Mini Project (notes-chart)

Full write-up: **[mini-project/README.md](mini-project/README.md)** (11 screenshots), including the **chart structure explanation** and the **templating notes** (`.Values`, `.Release`, `.Chart`, `define`/`include` helpers, `if`, `range`, `with`, `toYaml`, `required`, `checksum`).

Own chart `notes-chart` (Chart.yaml, values.yaml, values-prod.yaml, templates: deployment, service, configmap, `_helpers.tpl`, `NOTES.txt`), lint → template → install dev → install prod side by side → upgrade dev to prod values → broken upgrade → rollback → package → uninstall.

![dev vs prod rendering](mini-project/screenshots/03-template-dev-vs-prod.png)
![dev and prod side by side](mini-project/screenshots/06-dev-vs-prod-side-by-side.png)
![bad upgrade](mini-project/screenshots/08-bad-upgrade.png)
![rollback](mini-project/screenshots/09-rollback-to-rev2.png)

---

## Key observations

1. **Rollback = new revision.** `helm rollback rel N` re-applies revision N's *stored* manifest as revision N+k. The page in Task 2 still said `rendered-at-revision=2` while the release was at revision 4.
2. **"deployed" doesn't mean healthy** unless you use `--wait`/`--atomic`. In the mini project the broken-image release was `deployed`, while `--atomic` in Task 2 marked it `failed` and rolled back by itself.
3. **Rolling updates protect you.** During the bad upgrade the old pods kept serving, and rolling back simply scaled the old ReplicaSet back (same pod-template hash).
4. **`--reuse-values` vs a fresh upgrade:** a plain `helm upgrade` starts again from the chart defaults plus whatever `-f`/`--set` you pass now. `--reuse-values` carries over the previous release's values.
5. **Test hooks outlive the release** (`helm test` pod was left after `uninstall`) unless a `helm.sh/hook-delete-policy` is set.
6. **`helm template`/`lint`/`--dry-run` catch problems before the cluster does.** The `required` helper made a missing image repository a clear render error.

## Folder structure

```text
session-15-helm/
├── README.md                       # this summary
├── scripts/
│   ├── 00-prepull.sh               # pre-pulls nginx/busybox images into minikube
│   ├── 01-helm-commands.sh         # Task 1 (snap screenshots)
│   ├── 02-helm-rollback.sh         # Task 2
│   └── 03-mini-project.sh          # Task 3
├── 01-helm-commands/
│   ├── README.md
│   ├── webapp/                     # helm create output
│   ├── dist/                       # webapp-0.1.0.tgz, webapp-0.2.0.tgz
│   ├── screenshots/  outputs/      # 15 runs
├── 02-helm-rollback/
│   ├── README.md
│   ├── rollback-demo/              # Chart.yaml, values.yaml, values-v2.yaml, values-v3.yaml, templates/
│   ├── screenshots/  outputs/      # 13 runs
└── mini-project/
    ├── README.md
    ├── notes-chart/                # Chart.yaml, values.yaml, values-prod.yaml, templates/
    ├── dist/                       # notes-chart-0.1.0.tgz
    └── screenshots/  outputs/      # 11 runs
```

## How to reproduce

Requirements: a running minikube, `kubectl`, `helm` v3, and the `snap` helper (`tools/snap.sh` in this repo).

```bash
cd ~/devops-homework/session-15-helm
bash scripts/00-prepull.sh          # optional: speeds up the rollouts
bash scripts/01-helm-commands.sh    # Task 1 -> 01-helm-commands/{screenshots,outputs}
kubectl delete namespace s15
bash scripts/02-helm-rollback.sh    # Task 2 -> cleans up s15-rollback itself
bash scripts/03-mini-project.sh     # Task 3 -> cleans up s15-mini itself
```

All releases were uninstalled and the namespaces `s15`, `s15-rollback` and `s15-mini` were deleted at the end. The charts, values files, packaged `.tgz` files, screenshots and text outputs are kept.

## References

* Helm docs – https://helm.sh/docs/
* Chart template guide – https://helm.sh/docs/chart_template_guide/
* Helm CLI reference – https://helm.sh/docs/helm/
* Chart best practices – https://helm.sh/docs/chart_best_practices/
