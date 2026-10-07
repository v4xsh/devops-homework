# Session 21: Final DevOps Project

**Name:** Vansh Dobhal | **Roll No:** 10099

The complete project lives in [`final-devops-project/`](final-devops-project/README.md), using the folder layout the assignment requires:

| Folder | Contents |
|--------|----------|
| `application/` | TaskBoard: FastAPI backend (12 tests, 98% coverage) and React/Vite frontend |
| `docker/` | multi-stage, non-root Dockerfiles, nginx template, docker-compose stack |
| `kubernetes/` | Deployment, Service, ConfigMap, Secret, Ingress, HPA, probes, PostgreSQL StatefulSet + PVC |
| `helm/` | `taskboard` chart with dev/prod/gitops values and `helm test` |
| `terraform/` | AWS VPC + EKS + ECR + S3 (validated, fully planned, applied/destroyed on LocalStack) |
| `.github/workflows/` | CI/CD + DevSecOps pipeline (the copy GitHub actually runs is at the repo root: `.github/workflows/session21-final-pipeline.yml`) |
| `security/` | bandit / gitleaks / trivy configs, `security-gate.sh`, scan reports |
| `monitoring/` | ServiceMonitor, PrometheusRule, Grafana dashboard JSON, kube-prometheus-stack values |
| `gitops/` | Argo CD Applications (live demo through an in-cluster Gitea; GitHub version for after the push) |
| `troubleshooting/` | 6 intentionally broken scenarios, each with before/after screenshots |
| `README.md` | the full report: architecture, every stage, screenshots, honest notes on what was simulated, lessons learned |

Start with **[final-devops-project/README.md](final-devops-project/README.md)**.
