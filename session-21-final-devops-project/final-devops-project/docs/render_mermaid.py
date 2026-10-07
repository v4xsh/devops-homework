#!/usr/bin/env python3
"""Render docs/architecture.mmd to docs/architecture.png with mermaid.js in headless Chromium (Playwright)."""
import pathlib
import sys

from playwright.sync_api import sync_playwright

src = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "docs/architecture.mmd")
out = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "docs/architecture.png")
diagram = src.read_text()

html = f"""<!doctype html><html><head><meta charset="utf-8">
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<style>body{{margin:0;padding:24px;background:#fff;font-family:sans-serif}}</style></head>
<body><pre class="mermaid">{diagram}</pre>
<script>mermaid.initialize({{startOnLoad:true, theme:'default', flowchart:{{htmlLabels:true, curve:'basis'}}}});</script>
</body></html>"""

with sync_playwright() as pw:
    browser = pw.chromium.launch()
    page = browser.new_page(viewport={"width": 2200, "height": 1400}, device_scale_factor=1.5)
    page.set_content(html)
    page.wait_for_selector("pre.mermaid svg", timeout=30000)
    page.locator("pre.mermaid svg").screenshot(path=str(out))
    browser.close()
print(f"rendered {src} -> {out}")
