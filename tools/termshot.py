#!/usr/bin/env python3
"""Render a captured terminal session (real command + real output) as a macOS-style
terminal window PNG.

Input is a capture file written by tools/snap.sh:
    lines starting with "\x1e$ " are commands typed at the prompt,
    every other line is output produced by that command.
"""
import argparse
import os
import re
import textwrap

from PIL import Image, ImageDraw, ImageFont

ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07|\r")

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Regular.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    "C:/Windows/Fonts/consola.ttf",
]
BOLD_CANDIDATES = [
    "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
    "C:/Windows/Fonts/consolab.ttf",
]
UI_FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "C:/Windows/Fonts/segoeui.ttf",
]

BG = (30, 31, 41)
TITLEBAR = (54, 55, 66)
TITLE_FG = (200, 200, 210)
FG = (220, 223, 228)
PROMPT_USER = (80, 250, 123)
PROMPT_PATH = (98, 174, 239)
CMD_FG = (255, 255, 255)
DIM = (140, 145, 160)


def font(cands, size):
    for c in cands:
        if os.path.exists(c):
            return ImageFont.truetype(c, size)
    return ImageFont.load_default()


def parse(path):
    entries = []  # (kind, text)  kind in {"cmd", "out"}
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh.read().split("\n"):
            line = ANSI.sub("", raw).expandtabs(8)
            if line.startswith("\x1e$ "):
                body = line[3:]
                if "\x1f" in body:
                    cwd, _, cmd = body.partition("\x1f")
                else:
                    cwd, cmd = None, body
                entries.append(("cmd", (cwd, cmd)))
            else:
                entries.append(("out", line))
    return entries


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("capture")
    ap.add_argument("png")
    ap.add_argument("--title", default="")
    ap.add_argument("--prompt-user", default="vansh@Vansh-G15")
    ap.add_argument("--cwd", default="~")
    ap.add_argument("--cols", type=int, default=150)
    ap.add_argument("--max-lines", type=int, default=70)
    args = ap.parse_args()

    entries = parse(args.capture)
    cols = args.cols
    rows = []  # list of list of (text, color, bold)
    last_cwd = args.cwd
    for kind, text in entries:
        if kind == "cmd":
            cwd, cmd = text
            last_cwd = cwd or args.cwd
            rows.append([(args.prompt_user, PROMPT_USER, True), (":", FG, False),
                         (last_cwd, PROMPT_PATH, True), ("$ ", FG, False),
                         (cmd, CMD_FG, True)])
        else:
            wrapped = textwrap.wrap(text, cols, replace_whitespace=False,
                                    drop_whitespace=False) or [""]
            for w in wrapped:
                rows.append([(w, FG, False)])

    if len(rows) > args.max_lines:
        head = args.max_lines - 12
        omitted = len(rows) - args.max_lines + 1
        rows = rows[:head] + [[(f"... ({omitted} more lines) ...", DIM, False)]] + rows[-11:]

    # final idle prompt with cursor
    rows.append([(args.prompt_user, PROMPT_USER, True), (":", FG, False),
                 (args.cwd, PROMPT_PATH, True), ("$ ", FG, False), ("\u2588", FG, False)])

    size = 15
    f, fb = font(FONT_CANDIDATES, size), font(BOLD_CANDIDATES, size)
    uif = font(UI_FONT_CANDIDATES, 13)
    cw = f.getlength("M")
    lh = int(size * 1.45)

    longest = max(sum(len(t) for t, _, _ in r) for r in rows)
    content_w = int(min(max(longest, 70), cols + 25) * cw)
    pad, bar = 18, 30
    W = content_w + pad * 2
    H = bar + pad + len(rows) * lh + pad
    scale = 2  # retina-style
    img = Image.new("RGBA", (W * scale + 80, H * scale + 80), (0, 0, 0, 0))
    win = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(win)
    d.rectangle([0, 0, W, bar], fill=TITLEBAR)
    for i, col in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        cx = 18 + i * 20
        d.ellipse([cx - 6, bar / 2 - 6, cx + 6, bar / 2 + 6], fill=col)
    title = args.title or f"{args.prompt_user}: {last_cwd}"
    tw = d.textlength(title, font=uif)
    d.text(((W - tw) / 2, (bar - 14) / 2), title, fill=TITLE_FG, font=uif)

    y = bar + pad
    for r in rows:
        x = pad
        for text, colr, bold in r:
            fnt = fb if bold else f
            d.text((x, y), text, fill=colr, font=fnt)
            x += fnt.getlength(text)
        y += lh

    win = win.resize((W * scale, H * scale), Image.LANCZOS)
    mask = Image.new("L", win.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, win.size[0] - 1, win.size[1] - 1], 20, fill=255)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([40, 52, 40 + win.size[0], 52 + win.size[1]], 22,
                                             fill=(0, 0, 0, 90))
    try:
        from PIL import ImageFilter
        shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    except Exception:
        pass
    img = Image.alpha_composite(img, shadow)
    img.paste(win, (40, 40), mask)
    os.makedirs(os.path.dirname(os.path.abspath(args.png)), exist_ok=True)
    img.save(args.png, optimize=True)


if __name__ == "__main__":
    main()
