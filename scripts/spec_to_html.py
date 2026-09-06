#!/usr/bin/env python3
"""Tooling for GREEN_PYRAMID_SPECIFICATION.md.

Usage:
  python3 scripts/spec_to_html.py [in.md] [out.html]   render the HTML page (default)
  python3 scripts/spec_to_html.py --index [in.md]      write SPEC_INDEX.md, the compact build index
  python3 scripts/spec_to_html.py --trace [in.md]      cross-reference directive IDs against the code

Handles the narrow Markdown subset the specification uses: ATX headings, pipe
tables, unordered lists, ordered lists, blockquotes, horizontal rules, and the
inline run of bold / italic / code / strikethrough.
"""
import html
import os
import re
import sys

_args = sys.argv[1:]
MODE = _args[0] if _args and _args[0].startswith("--") else None
if MODE:
    _args = _args[1:]
SRC = _args[0] if _args else "GREEN_PYRAMID_SPECIFICATION.md"
OUT = _args[1] if len(_args) > 1 else "GREEN_PYRAMID_SPECIFICATION.html"

# Authority level per top-level part, used to style the section chrome.
AUTHORITY = {
    "PART I": ("interpretive", "Interpretive"),
    "PART II": ("factual", "Factual"),
    "PART III": ("binding", "Binding"),
    "PART IV": ("binding", "Binding"),
    "OPEN QUESTIONS": ("open", "Unresolved"),
    "APPENDIX": ("factual", "Reference"),
}


def slug(text):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s or "section"


def inline(text):
    t = html.escape(text, quote=False)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"~~([^~]+)~~", r"<del>\1</del>", t)
    t = re.sub(r"(?<![*\w])\*([^*]+)\*(?!\*)", r"<em>\1</em>", t)
    t = t.replace("—", "&#8212;")
    return t


class Renderer:
    def __init__(self, lines):
        self.lines = lines
        self.i = 0
        self.out = []
        self.nav = []
        self.section_open = False
        self.block_open = False

    def peek(self, k=0):
        j = self.i + k
        return self.lines[j] if j < len(self.lines) else None

    def close_block(self):
        if self.block_open:
            self.out.append("</div>")
            self.block_open = False

    def close_section(self):
        self.close_block()
        if self.section_open:
            self.out.append("</section>")
            self.section_open = False

    def run(self):
        while self.i < len(self.lines):
            line = self.lines[self.i]
            stripped = line.strip()

            if not stripped:
                self.i += 1
                continue
            if stripped == "---":
                self.i += 1
                continue
            if stripped.startswith("|"):
                self.table()
                continue
            if stripped.startswith("> "):
                self.blockquote()
                continue
            if re.match(r"^[-*] ", stripped):
                self.ulist()
                continue
            if re.match(r"^\d+\. ", stripped):
                self.olist()
                continue
            if stripped.startswith("#"):
                self.heading(stripped)
                self.i += 1
                continue
            self.paragraph()

        self.close_section()
        return "\n".join(self.out), self.nav

    # --- block handlers -------------------------------------------------
    def heading(self, stripped):
        level = len(stripped) - len(stripped.lstrip("#"))
        text = stripped[level:].strip()
        anchor = slug(text)

        self.close_block()

        if level == 1:
            self.close_section()
            key = next((k for k in AUTHORITY if text.startswith(k)), None)
            cls, label = AUTHORITY.get(key, ("factual", ""))
            self.out.append(f'<section class="part part--{cls}" id="{anchor}">')
            self.section_open = True
            badge = f'<span class="authority">{label}</span>' if label else ""
            self.out.append(
                f'<header class="part__head">{badge}'
                f'<h2 class="part__title">{inline(text)}</h2></header>'
            )
            self.nav.append(("part", text, anchor))
            return

        # Directive / principle / question blocks get an ID chip pulled out.
        m = re.match(r"^([PDQ]-\d+[a-z]?)\.?\s*[.—-]?\s*(.*)$", text)
        tag = "h3" if level == 2 else "h4"
        if m:
            ident, rest = m.group(1), m.group(2)
            kind = {"P": "principle", "D": "directive", "Q": "question"}[ident[0]]
            self.out.append(f'<div class="block block--{kind}" id="{anchor}">')
            self.out.append(
                f'<{tag} class="block__head"><span class="chip chip--{kind}">'
                f"{ident}</span><span class=\"block__title\">{inline(rest)}</span></{tag}>"
            )
            self.block_open = True
            self.nav.append((kind, f"{ident} {rest}", anchor))
            return

        self.out.append(f'<{tag} class="sub" id="{anchor}">{inline(text)}</{tag}>')
        self.nav.append(("sub", text, anchor))

    def table(self):
        rows = []
        while self.peek() is not None and self.peek().strip().startswith("|"):
            rows.append([c.strip() for c in self.peek().strip().strip("|").split("|")])
            self.i += 1
        if len(rows) >= 2 and set(rows[1][0].replace(" ", "")) <= set("-:"):
            head, body = rows[0], rows[2:]
        else:
            head, body = None, rows
        self.out.append('<div class="tablewrap"><table>')
        if head:
            self.out.append(
                "<thead><tr>"
                + "".join(f"<th>{inline(c)}</th>" for c in head)
                + "</tr></thead>"
            )
        self.out.append("<tbody>")
        for r in body:
            cells = "".join(f"<td>{inline(c)}</td>" for c in r)
            self.out.append(f"<tr>{cells}</tr>")
        self.out.append("</tbody></table></div>")

    def blockquote(self):
        parts = []
        while self.peek() is not None and self.peek().strip().startswith(">"):
            parts.append(self.peek().strip().lstrip(">").strip())
            self.i += 1
        self.out.append(f'<blockquote>{inline(" ".join(parts))}</blockquote>')

    def ulist(self):
        items = []
        while self.peek() is not None and re.match(r"^[-*] ", self.peek().strip()):
            items.append(self.peek().strip()[2:])
            self.i += 1
        body = "".join(f"<li>{inline(x)}</li>" for x in items)
        self.out.append(f"<ul>{body}</ul>")

    def olist(self):
        items = []
        while self.peek() is not None and re.match(r"^\d+\. ", self.peek().strip()):
            items.append(re.sub(r"^\d+\.\s*", "", self.peek().strip()))
            self.i += 1
        body = "".join(f"<li>{inline(x)}</li>" for x in items)
        self.out.append(f"<ol>{body}</ol>")

    def paragraph(self):
        buf = []
        while self.peek() is not None:
            s = self.peek().strip()
            if not s or s.startswith(("#", "|", "> ", "---")) or re.match(r"^([-*]|\d+\.) ", s):
                break
            buf.append(s)
            self.i += 1
        text = " ".join(buf)
        cls = ""
        if text.startswith("**Status:**"):
            status = re.sub(r"[^a-z]", "", text.split("`")[1]) if "`" in text else "unknown"
            self.out.append(
                f'<p class="status status--{status}">'
                f'<span class="status__dot"></span>{status}</p>'
            )
            return
        if text.startswith("**Decision:**"):
            cls = ' class="lede"'
        elif text.startswith("**Acceptance criteria:**"):
            cls = ' class="ac"'
        elif text.startswith("**Rationale:**"):
            cls = ' class="rationale"'
        self.out.append(f"<p{cls}>{inline(text)}</p>")


def build_nav(nav):
    items = []
    for kind, text, anchor in nav:
        if kind == "part":
            items.append(f'<a class="nav__part" href="#{anchor}">{html.escape(text)}</a>')
        elif kind == "sub":
            items.append(f'<a class="nav__sub" href="#{anchor}">{html.escape(text)}</a>')
        elif kind in ("directive", "principle"):
            ident, _, rest = text.partition(" ")
            items.append(
                f'<a class="nav__leaf" href="#{anchor}">'
                f'<span class="nav__id">{ident}</span>'
                f"<span>{html.escape(rest)}</span></a>"
            )
    return "\n".join(items)


def directive_table(text):
    """[(id, title, status)] for every directive, in document order."""
    rows = []
    lines = text.split("\n")
    for i, ln in enumerate(lines):
        m = re.match(r"^### (D-\d+) — (.*)$", ln)
        if not m:
            continue
        status = "unknown"
        for look in lines[i + 1 : i + 4]:
            sm = re.match(r"^\*\*Status:\*\*\s*`([a-z]+)`", look)
            if sm:
                status = sm.group(1)
                break
        rows.append((m.group(1), m.group(2), status))
    return rows


def write_index(text, path="SPEC_INDEX.md"):
    rows = directive_table(text)
    counts = {}
    for _, _, st in rows:
        counts[st] = counts.get(st, 0) + 1
    out = [
        "# Green Pyramid — Directive Index",
        "",
        "Generated by `scripts/spec_to_html.py --index`. Do not edit by hand.",
        "",
        "Read this file to find the directive you need, then read only that directive "
        "from `GREEN_PYRAMID_SPECIFICATION.md`. Never load the full specification "
        "into context automatically (D-081).",
        "",
        "  ".join(f"**{k}** {v}" for k, v in sorted(counts.items())),
        "",
    ]
    section = None
    for line in text.split("\n"):
        hm = re.match(r"^## (III-[A-Z]\. .*)$", line)
        if hm:
            section = hm.group(1)
            continue
        dm = re.match(r"^### (D-\d+) — (.*)$", line)
        if dm:
            if section:
                out += ["", f"### {section}", ""]
                section = None
            did, title = dm.group(1), dm.group(2)
            st = next(s for i, t, s in rows if i == did)
            out.append(f"- `{did}` [{st}] {title}")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")
    return path, len(rows)


def trace(text, roots=("lib", "test", "integration_test", "backend", "functions")):
    """Cross-reference directive IDs in the code against the specification (D-080)."""
    rows = directive_table(text)
    known = {i for i, _, _ in rows}
    in_tests, in_code = {}, {}
    for root in roots:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in ("node_modules", "build", ".dart_tool")]
            for fn in filenames:
                if not fn.endswith((".dart", ".js", ".ts", ".mjs")):
                    continue
                fp = os.path.join(dirpath, fn)
                try:
                    body = open(fp, encoding="utf-8", errors="replace").read()
                except OSError:
                    continue
                for did in set(re.findall(r"\bD-\d{3}\b", body)):
                    bucket = in_tests if fn.endswith("_test.dart") or "/test" in fp else in_code
                    bucket.setdefault(did, []).append(fp)

    problems = []
    for did, title, st in rows:
        if st == "done" and did not in in_tests:
            problems.append(("BLOCKER", did, "marked done but no test names it"))
        if st in ("done", "building") and did not in in_tests and did not in in_code:
            problems.append(("WARN", did, f"marked {st} but no code reference found"))
    for did in sorted(set(in_tests) | set(in_code)):
        if did not in known:
            where = (in_tests.get(did) or in_code.get(did))[0]
            problems.append(("ERROR", did, f"referenced in {where} but not in the specification"))

    counts = {}
    for _, _, st in rows:
        counts[st] = counts.get(st, 0) + 1
    print(f"directives: {len(rows)}  " + "  ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    print(f"referenced in tests: {len(in_tests)}   referenced in code: {len(in_code)}")
    if not problems:
        print("\nOK - no traceability problems.")
        return 0
    print()
    for level, did, msg in problems:
        print(f"  {level:<8} {did}  {msg}")
    return 1 if any(p[0] in ("BLOCKER", "ERROR") for p in problems) else 0


if MODE in ("--index", "--trace"):
    with open(SRC, encoding="utf-8") as fh:
        _text = fh.read()
    if MODE == "--index":
        path, n = write_index(_text)
        print(f"wrote {path} ({n} directives)")
        sys.exit(0)
    sys.exit(trace(_text))


with open(SRC, encoding="utf-8") as fh:
    raw = fh.read()

# Strip the H1 and the leading metadata block; they are rebuilt as the masthead.
lines = raw.split("\n")
meta = {}
for ln in lines[:8]:
    m = re.match(r"^\*\*(.+?):\*\*\s*(.+)$", ln.strip())
    if m:
        meta[m.group(1)] = m.group(2)
start = 0
for idx, ln in enumerate(lines):
    if ln.strip() == "## How To Read This Document":
        start = idx
        break
body_html, nav = Renderer(lines[start:]).run()

counts = {
    "directives": len(re.findall(r"^### D-\d+", raw, re.M)),
    "principles": len(re.findall(r"^## P-\d+", raw, re.M)),
    "open": len(re.findall(r"^\| `Q-\d+` \| (?!~~)", raw, re.M)),
    "decisions": len(re.findall(r"^\| \d+ \| 20", raw, re.M)),
}

TEMPLATE = """<title>Green Pyramid Specification</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,600&family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&display=swap">
<style>
:root {
  --ground: #FBFCFA;
  --surface: #F1F4F0;
  --surface-2: #E7ECE6;
  --ink: #16211B;
  --muted: #5C6B62;
  --line: #D8E0D8;
  --line-soft: #E8EDE7;
  --accent: #1F7A4C;
  --accent-soft: #DCEBE1;
  --amber: #A86A18;
  --amber-soft: #F6EBD8;
  --measure: 68ch;
  --sans: "IBM Plex Sans", ui-sans-serif, system-ui, -apple-system, sans-serif;
  --serif: "Fraunces", Georgia, "Times New Roman", serif;
  --mono: "IBM Plex Mono", ui-monospace, SFMono-Regular, Menlo, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --ground: #0D1512;
    --surface: #14201B;
    --surface-2: #1B2A23;
    --ink: #E3ECE6;
    --muted: #93A69B;
    --line: #26372E;
    --line-soft: #1D2C25;
    --accent: #56C089;
    --accent-soft: #17301F;
    --amber: #D9A055;
    --amber-soft: #2C2314;
  }
}
:root[data-theme="dark"] {
  --ground: #0D1512;
  --surface: #14201B;
  --surface-2: #1B2A23;
  --ink: #E3ECE6;
  --muted: #93A69B;
  --line: #26372E;
  --line-soft: #1D2C25;
  --accent: #56C089;
  --accent-soft: #17301F;
  --amber: #D9A055;
  --amber-soft: #2C2314;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--ground);
  color: var(--ink);
  font-family: var(--sans);
  font-size: 16px;
  line-height: 1.65;
  -webkit-font-smoothing: antialiased;
}
a { color: var(--accent); }
code {
  font-family: var(--mono);
  font-size: 0.86em;
  background: var(--surface-2);
  padding: 0.12em 0.36em;
  border-radius: 3px;
  overflow-wrap: anywhere;
}
del { color: var(--muted); text-decoration-thickness: 1px; }

/* ---- shell ---- */
.shell { display: grid; grid-template-columns: 17rem minmax(0, 1fr); gap: 3.5rem; max-width: 92rem; margin: 0 auto; padding: 0 2rem; }
.rail { position: sticky; top: 0; align-self: start; height: 100vh; overflow-y: auto; padding: 2.5rem 0 4rem; border-right: 1px solid var(--line-soft); }
.rail::-webkit-scrollbar { width: 6px; }
.rail::-webkit-scrollbar-thumb { background: var(--line); border-radius: 3px; }
.main { min-width: 0; padding: 2.5rem 0 8rem; }

/* ---- masthead ---- */
.masthead { border-bottom: 1px solid var(--line); padding-bottom: 2.25rem; margin-bottom: 3rem; }
.eyebrow { font-family: var(--mono); font-size: 0.7rem; letter-spacing: 0.14em; text-transform: uppercase; color: var(--muted); margin: 0 0 1rem; }
.masthead h1 { font-family: var(--serif); font-optical-sizing: auto; font-weight: 600; font-size: clamp(2.4rem, 5vw, 3.6rem); line-height: 1.04; letter-spacing: -0.02em; margin: 0 0 1.25rem; text-wrap: balance; }
.masthead h1 em { font-style: normal; color: var(--accent); }
.meta { display: flex; flex-wrap: wrap; gap: 0.5rem 1.75rem; font-size: 0.85rem; color: var(--muted); margin: 0 0 2rem; }
.meta b { color: var(--ink); font-weight: 500; }
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(8rem, 1fr)); gap: 1px; background: var(--line-soft); border: 1px solid var(--line-soft); border-radius: 6px; overflow: hidden; }
.stat { background: var(--ground); padding: 0.9rem 1.1rem; }
.stat__n { font-family: var(--serif); font-size: 1.9rem; font-weight: 600; line-height: 1; font-variant-numeric: tabular-nums; }
.stat--open .stat__n { color: var(--amber); }
.stat__l { font-family: var(--mono); font-size: 0.66rem; letter-spacing: 0.1em; text-transform: uppercase; color: var(--muted); margin-top: 0.4rem; }

/* ---- nav ---- */
.nav__part { display: block; font-family: var(--mono); font-size: 0.7rem; letter-spacing: 0.1em; text-transform: uppercase; color: var(--ink); text-decoration: none; margin: 1.75rem 0 0.5rem; padding-right: 1rem; }
.nav__part:first-child { margin-top: 0; }
.nav__sub { display: block; font-size: 0.8rem; color: var(--muted); text-decoration: none; padding: 0.2rem 1rem 0.2rem 0.75rem; border-left: 1px solid var(--line-soft); }
.nav__leaf { display: grid; grid-template-columns: 3.6rem 1fr; gap: 0.4rem; font-size: 0.78rem; color: var(--muted); text-decoration: none; padding: 0.22rem 1rem 0.22rem 0.75rem; border-left: 1px solid var(--line-soft); }
.nav__id { font-family: var(--mono); font-size: 0.72rem; color: var(--accent); }
.nav__sub:hover, .nav__leaf:hover { color: var(--ink); border-left-color: var(--accent); background: var(--surface); }
a:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; border-radius: 2px; }

/* ---- parts ---- */
.part { margin: 0 0 5rem; }
.part__head { display: flex; align-items: baseline; gap: 1rem; flex-wrap: wrap; padding-bottom: 0.9rem; margin-bottom: 2.25rem; border-bottom: 2px solid var(--ink); }
.part__title { font-family: var(--serif); font-weight: 600; font-size: clamp(1.5rem, 3vw, 2.1rem); letter-spacing: -0.015em; margin: 0; }
.authority { font-family: var(--mono); font-size: 0.64rem; letter-spacing: 0.12em; text-transform: uppercase; padding: 0.2rem 0.55rem; border-radius: 999px; border: 1px solid var(--line); color: var(--muted); }
.part--binding .part__head { border-bottom-color: var(--accent); }
.part--binding .authority { color: var(--accent); border-color: var(--accent); background: var(--accent-soft); }
.part--open .part__head { border-bottom-color: var(--amber); }
.part--open .authority { color: var(--amber); border-color: var(--amber); background: var(--amber-soft); }

/* ---- content blocks ---- */
.main > .part > *,
.part > * { max-width: var(--measure); }
.tablewrap, .part__head { max-width: none; }
.sub { font-family: var(--sans); font-weight: 600; font-size: 1.02rem; letter-spacing: 0.01em; margin: 3rem 0 1rem; padding-bottom: 0.5rem; border-bottom: 1px solid var(--line-soft); color: var(--muted); }
h4.sub { margin-top: 2.25rem; }
p { margin: 0 0 1rem; }
ul, ol { margin: 0 0 1.15rem; padding-left: 1.15rem; }
li { margin-bottom: 0.35rem; }
li::marker { color: var(--muted); }

.block { margin: 2.5rem 0 0.5rem; }
.block__head { display: flex; align-items: baseline; gap: 0.85rem; flex-wrap: wrap; margin: 0; font-size: 1.06rem; font-weight: 600; line-height: 1.35; }
.block__title { flex: 1 1 18rem; text-wrap: balance; }
.chip { font-family: var(--mono); font-size: 0.72rem; font-weight: 500; letter-spacing: 0.04em; padding: 0.16rem 0.5rem; border-radius: 4px; white-space: nowrap; }
.chip--directive { background: var(--accent); color: var(--ground); }
.chip--principle { background: var(--surface-2); color: var(--ink); border: 1px solid var(--line); }
.chip--question { background: var(--amber-soft); color: var(--amber); border: 1px solid var(--amber); }

/* Authority is encoded in the chrome: binding directives are bounded and
   carry a solid accent rail; interpretive principles get only a hairline. */
.block--directive { border-left: 3px solid var(--accent); background: var(--surface); border-radius: 0 6px 6px 0; padding: 1.25rem 1.5rem 1.4rem; }
.block--directive > .block__head { margin-bottom: 0.9rem; }
.block--directive > :last-child { margin-bottom: 0; }
.block--principle { border-left: 1px solid var(--line); padding: 0.1rem 0 0.1rem 1.35rem; }
.block--question { border-left: 2px solid var(--amber); padding: 0.1rem 0 0.1rem 1.35rem; }
.block .tablewrap { max-width: none; }

p.lede { font-size: 1.02rem; }
.status { display: inline-flex; align-items: center; gap: 0.45rem; font-family: var(--mono); font-size: 0.66rem; letter-spacing: 0.1em; text-transform: uppercase; color: var(--muted); margin: 0 0 1rem; padding: 0.18rem 0.6rem 0.18rem 0.5rem; border: 1px solid var(--line); border-radius: 999px; }
.status__dot { width: 6px; height: 6px; border-radius: 50%; background: currentColor; }
.status--drafted { color: var(--muted); }
.status--building { color: var(--amber); border-color: var(--amber); background: var(--amber-soft); }
.status--done { color: var(--accent); border-color: var(--accent); background: var(--accent-soft); }
.status--superseded { color: var(--muted); opacity: 0.6; text-decoration: line-through; }
p.ac, p.rationale { font-family: var(--mono); font-size: 0.7rem; letter-spacing: 0.1em; text-transform: uppercase; color: var(--muted); margin: 1.4rem 0 0.5rem; }

blockquote { margin: 1.5rem 0; padding: 1.15rem 1.4rem; background: var(--surface); border-left: 3px solid var(--accent);
.block--directive blockquote, .block--principle blockquote { background: var(--ground); border: 1px solid var(--line); border-left: 3px solid var(--accent); } border-radius: 0 4px 4px 0; font-family: var(--serif); font-size: 1.1rem; line-height: 1.5; }

/* ---- tables ---- */
.tablewrap { overflow-x: auto; margin: 1.25rem 0 1.75rem; border: 1px solid var(--line-soft); border-radius: 6px; }
table { border-collapse: collapse; width: 100%; font-size: 0.86rem; }
th, td { text-align: left; padding: 0.6rem 0.9rem; border-bottom: 1px solid var(--line-soft); vertical-align: top; }
th { font-family: var(--mono); font-size: 0.68rem; letter-spacing: 0.09em; text-transform: uppercase; color: var(--muted); background: var(--surface); font-weight: 500; white-space: nowrap; }
tbody tr:last-child td { border-bottom: 0; }
tbody tr:hover { background: var(--surface); }
td:first-child { font-variant-numeric: tabular-nums; }

@media (max-width: 62rem) {
  .shell { grid-template-columns: 1fr; gap: 0; padding: 0 1.25rem; }
  .rail { position: static; height: auto; border-right: 0; border-bottom: 1px solid var(--line-soft); padding: 1.5rem 0; max-height: 15rem; }
  .main { padding-top: 2rem; }
}
@media (prefers-reduced-motion: reduce) { * { animation: none !important; transition: none !important; } }
</style>

<div class="shell">
  <nav class="rail" aria-label="Specification contents">
__NAV__
  </nav>
  <main class="main">
    <header class="masthead">
      <p class="eyebrow">Product &amp; Engineering Specification</p>
      <h1>Green <em>Pyramid</em></h1>
      <div class="meta">
        <span><b>Status</b> __STATUS__</span>
        <span><b>Applies to</b> __APPLIES__</span>
        <span><b>Owner</b> __OWNER__</span>
      </div>
      <div class="stats">
        <div class="stat"><div class="stat__n">__NDIR__</div><div class="stat__l">Directives</div></div>
        <div class="stat"><div class="stat__n">__NPRIN__</div><div class="stat__l">Principles</div></div>
        <div class="stat stat--open"><div class="stat__n">__NOPEN__</div><div class="stat__l">Open questions</div></div>
        <div class="stat"><div class="stat__n">__NDEC__</div><div class="stat__l">Decisions logged</div></div>
      </div>
    </header>
__BODY__
  </main>
</div>
"""

page = (
    TEMPLATE.replace("__NAV__", build_nav(nav))
    .replace("__BODY__", body_html)
    .replace("__STATUS__", html.escape(meta.get("Status", "In definition")))
    .replace("__APPLIES__", html.escape(meta.get("Applies to", "").replace("`", "")))
    .replace("__OWNER__", html.escape(meta.get("Document owner", "")))
    .replace("__NDIR__", str(counts["directives"]))
    .replace("__NPRIN__", str(counts["principles"]))
    .replace("__NOPEN__", str(counts["open"]))
    .replace("__NDEC__", str(counts["decisions"]))
)

with open(OUT, "w", encoding="utf-8") as fh:
    fh.write(page)
print(f"wrote {OUT} ({len(page):,} bytes)")

# D-081: the index regenerates alongside the HTML whenever the spec changes.
_idx, _n = write_index(raw)
print(f"wrote {_idx} ({_n} directives)")
