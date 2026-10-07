# DevOps Homework — Section A

**Name:** Vansh Dobhal | **Roll No:** 10099 | **GitHub:** [v4xsh](https://github.com/v4xsh)

One repository, one folder per session. Every folder has its own `README.md` with the task list, files, commands, real command output (`outputs/*.txt`) and terminal screenshots (`screenshots/*.png`).

| # | Session | README |
|---|---------|--------|
| 1 & 2 | Linux Fundamentals | [session-01-02-linux-fundamentals](session-01-02-linux-fundamentals/README.md) |
| 3 | Shell Scripting | [session-03-shell-scripting](session-03-shell-scripting/README.md) |
| 4 | Networking | [session-04-networking](session-04-networking/README.md) |
| 5 | Git and GitHub | [session-05-git-github](session-05-git-github/README.md) |
| 6 | Docker Fundamentals | [session-06-docker-fundamentals](session-06-docker-fundamentals/README.md) |
| 7 | Docker Images | [session-07-docker-images](session-07-docker-images/README.md) |
| 8 | Docker Networking & Volumes | [session-08-docker-networking](session-08-docker-networking/README.md) |
| 9 | Kubernetes Fundamentals | [session-09-kubernetes-fundamentals](session-09-kubernetes-fundamentals/README.md) |
| 10 | Kubernetes Pods, ReplicaSets & Deployments | [session-10-pods-replicasets-deployments](session-10-pods-replicasets-deployments/README.md) |
| 11 | Kubernetes Networking & Services | [session-11-kubernetes-networking-services](session-11-kubernetes-networking-services/README.md) |
| 12 | Kubernetes Ingress, ConfigMaps & Secrets | [session-12-ingress-configmaps-secrets](session-12-ingress-configmaps-secrets/README.md) |
| 13 | Kubernetes Storage, HPA & Probes | [session-13-storage-hpa-probes](session-13-storage-hpa-probes/README.md) |
| 14 | Kubernetes Troubleshooting | [session-14-kubernetes-troubleshooting](session-14-kubernetes-troubleshooting/README.md) |
| 15 | Helm | [session-15-helm](session-15-helm/README.md) |
| 16 | CI/CD & GitHub Actions | [session-16-cicd-github-actions](session-16-cicd-github-actions/README.md) |
| 17 | Complete CI/CD & DevSecOps | [session-17-devsecops](session-17-devsecops/README.md) |
| 18 | Terraform & Infrastructure as Code | [session-18-terraform-iac](session-18-terraform-iac/README.md) |
| 19 | Cloud & Terraform in Action | [session-19-cloud-terraform](session-19-cloud-terraform/README.md) |
| 20 | Monitoring, Observability & GitOps | [session-20-monitoring-observability-gitops](session-20-monitoring-observability-gitops/README.md) |
| 21 | Final DevOps Project & Troubleshooting | [session-21-final-devops-project/final-devops-project](session-21-final-devops-project/final-devops-project/README.md) |

## Lab environment

All hands-on work was done on my laptop (`Vansh-G15`, Windows 11) inside **Ubuntu 24.04 on WSL2**:

- Docker Engine, minikube (docker driver) with ingress + metrics-server addons, kubectl, Helm 3
- Terraform with **LocalStack** as the AWS endpoint (no paid AWS account was used — see Sessions 18/19 READMEs)
- GitHub Actions workflows in [.github/workflows](.github/workflows) — run locally with **act** before pushing, and on GitHub from the Actions tab after pushing
- Trivy, Gitleaks, Bandit, Semgrep, pip-audit for DevSecOps

Screenshots were captured with the small helper in [tools/](tools/README.md), which runs the commands and saves the real output as an image and a text log.
