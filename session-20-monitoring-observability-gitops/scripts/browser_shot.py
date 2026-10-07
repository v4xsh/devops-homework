#!/usr/bin/env python3
"""Take REAL screenshots of web UIs (Prometheus, Grafana, Alertmanager, Jaeger, Argo CD) with headless Chromium.

usage: browser_shot.py <url> <out.png> [--wait-ms N] [--grafana-login user:pass] [--argocd-login user:pass]
                       [--width W] [--height H] [--click-text TEXT] [--full]
"""
import argparse
import sys

from playwright.sync_api import sync_playwright

p = argparse.ArgumentParser()
p.add_argument("url")
p.add_argument("out")
p.add_argument("--wait-ms", type=int, default=4000)
p.add_argument("--grafana-login")
p.add_argument("--argocd-login")
p.add_argument("--width", type=int, default=1600)
p.add_argument("--height", type=int, default=900)
p.add_argument("--click-text", action="append", default=[])
p.add_argument("--full", action="store_true")
a = p.parse_args()

with sync_playwright() as pw:
    browser = pw.chromium.launch()
    ctx = browser.new_context(viewport={"width": a.width, "height": a.height}, ignore_https_errors=True)
    page = ctx.new_page()
    if a.grafana_login:
        user, pwd = a.grafana_login.split(":", 1)
        base = a.url.split("/d/")[0].split("/explore")[0].rstrip("/")
        base = "/".join(a.url.split("/")[:3])
        page.goto(base + "/login")
        page.fill("input[name=user]", user)
        page.fill("input[name=password]", pwd)
        page.click("button[type=submit]")
        page.wait_for_timeout(2500)
    if a.argocd_login:
        user, pwd = a.argocd_login.split(":", 1)
        base = "/".join(a.url.split("/")[:3])
        page.goto(base + "/login")
        page.wait_for_selector("input[name=username]", timeout=20000)
        page.fill("input[name=username]", user)
        page.fill("input[name=password]", pwd)
        page.click("button:has-text('Sign In')")
        page.wait_for_timeout(3000)
    page.goto(a.url, wait_until="load", timeout=60000)
    for t in a.click_text:
        try:
            page.get_by_text(t, exact=False).first.click(timeout=5000)
            page.wait_for_timeout(1000)
        except Exception as e:  # keep going - the screenshot shows what really rendered
            print(f"click '{t}' failed: {e}", file=sys.stderr)
    page.wait_for_timeout(a.wait_ms)
    page.screenshot(path=a.out, full_page=a.full)
    print(f"[browser_shot] {a.url} -> {a.out}")
    browser.close()
