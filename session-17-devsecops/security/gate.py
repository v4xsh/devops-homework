#!/usr/bin/env python3
"""Security gate: read every scanner report and decide if the pipeline may continue.

Policy (fail closed):
  * SAST   - Bandit findings with severity HIGH, Semgrep findings with severity ERROR
  * SCA    - pip-audit: any known vulnerability that has a fixed version
             Trivy fs : HIGH/CRITICAL vulnerabilities with a fix (filtered by trivy.yaml)
  * Image  - Trivy image: HIGH/CRITICAL vulnerabilities with a fix
  * Secret - any Gitleaks finding (the secret-scan job already stops the pipeline, the gate re-checks)
  * A missing report counts as a failure - a scanner that did not run cannot say "clean".

usage: gate.py <reports-dir>      exit 0 = pass, exit 1 = blocked
"""
import json
import os
import sys
from pathlib import Path

BLOCKING_SEVERITIES = set(os.environ.get("GATE_SEVERITIES", "HIGH,CRITICAL").split(","))


def load(path: Path):
    if not path.exists():
        return None
    text = path.read_text() or "null"
    return json.loads(text)


def bandit(data):
    findings = [r for r in data.get("results", []) if r.get("issue_severity") in BLOCKING_SEVERITIES]
    return len(findings), [f"{r['test_id']} {r['filename']}:{r['line_number']} {r['issue_text']}"
                           for r in findings]


def semgrep(data):
    findings = [r for r in data.get("results", []) if r.get("extra", {}).get("severity") == "ERROR"]
    return len(findings), [f"{r['check_id']} {r['path']}:{r['start']['line']}" for r in findings]


def pip_audit(data):
    rows = []
    for dep in data.get("dependencies", []):
        for vuln in dep.get("vulns", []):
            if vuln.get("fix_versions"):
                rows.append(f"{dep['name']}=={dep['version']} {vuln['id']} "
                            f"(fixed in {', '.join(vuln['fix_versions'])})")
    return len(rows), rows


def trivy(data):
    rows = []
    for result in data.get("Results", []) or []:
        for v in result.get("Vulnerabilities", []) or []:
            if v.get("Severity") in BLOCKING_SEVERITIES:
                rows.append(f"{v['Severity']:8} {v['VulnerabilityID']:20} {v['PkgName']} "
                            f"{v.get('InstalledVersion', '')} -> {v.get('FixedVersion', '')}")
    return len(rows), rows


def gitleaks(data):
    return len(data), [f"{f.get('RuleID')} {f.get('File')}:{f.get('StartLine')}" for f in data]


CHECKS = [
    ("SAST", "Bandit (HIGH)", "bandit.json", bandit),
    ("SAST", "Semgrep (ERROR)", "semgrep.json", semgrep),
    ("SCA", "pip-audit (fixable)", "pip-audit.json", pip_audit),
    ("SCA", "Trivy fs (HIGH/CRITICAL)", "trivy-fs.json", trivy),
    ("Secrets", "Gitleaks", "gitleaks.json", gitleaks),
    ("Image", "Trivy image (HIGH/CRITICAL)", "trivy-image.json", trivy),
]


def main() -> int:
    reports = Path(sys.argv[1] if len(sys.argv) > 1 else "reports")
    summary = ["| Stage | Check | Blocking findings | Result |", "|---|---|---|---|"]
    blocked = False
    print(f"Security gate - blocking severities: {', '.join(sorted(BLOCKING_SEVERITIES))}")
    print(f"{'STAGE':8} {'CHECK':30} {'BLOCKING':>8}  RESULT")
    details = []
    for stage, name, filename, parser in CHECKS:
        data = load(reports / filename)
        if data is None:
            count, rows, result = "-", [], "FAIL (report missing)"
            blocked = True
        else:
            count, rows = parser(data)
            result = "PASS" if count == 0 else "FAIL"
            blocked = blocked or count > 0
        print(f"{stage:8} {name:30} {count!s:>8}  {result}")
        summary.append(f"| {stage} | {name} | {count} | {result} |")
        details.extend(f"  [{name}] {row}" for row in rows[:15])
        if len(rows) > 15:
            details.append(f"  [{name}] ... and {len(rows) - 15} more")
    if details:
        print("\nBlocking findings:")
        print("\n".join(details))
    verdict = "BLOCKED - fix the findings above before this image can be pushed/deployed" \
        if blocked else "PASSED - image may be pushed and deployed"
    print(f"\nSECURITY GATE: {verdict}")
    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a") as fh:
            fh.write("## Security gate\n\n" + "\n".join(summary) + f"\n\n**{verdict}**\n")
    return 1 if blocked else 0


if __name__ == "__main__":
    sys.exit(main())
