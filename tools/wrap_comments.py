"""Re-flows the comments of R files to 80 columns (the tidyverse style guide), after Air has formatted the code.

    python3 tools/wrap_comments.py R/*.R tests/testthat/*.R tools/*.R
    python3 tools/wrap_comments.py --examples path/to/air R/*.R        (the code of the examples, with Air)

* roxygen blocks (#'): paragraphs, the text of tags and bullet points are re-flowed; examples, code blocks and tables
  are left as they are;
* plain comments (#): paragraphs of whole-line comments are re-flowed, unless they are laid out in columns (two spaces
  inside the text); lines of = or - are shortened;
* a comment at the end of a line of code that makes the line too long moves to its own line, above the code.
"""
import re
import sys
import textwrap

WIDTH = 80


def wrap(text, first, rest):
    return textwrap.wrap(text, width=WIDTH, initial_indent=first, subsequent_indent=rest,
                         break_long_words=False, break_on_hyphens=False) or [first.rstrip()]


def roxygen_block(lines, indent):
    out, i, in_code, in_examples = [], 0, False, False
    pre = indent + "#'"
    items = []                       # (kind, first_prefix, rest_prefix, text) or ("raw", line)
    for l in lines:
        body = l[len(pre):]
        txt = body[1:] if body.startswith(" ") else body
        if txt.startswith("```"):
            in_code = not in_code
            items.append(("raw", l)); continue
        if in_code or in_examples:
            if txt.startswith("@") and not txt.startswith("@examples"):
                in_examples = False
            else:
                items.append(("raw", l)); continue
        if txt.startswith("@examples"):
            in_examples = True
            items.append(("raw", l)); continue
        if not txt.strip() or txt.lstrip().startswith("|") or re.match(r"^\s*\S.*\S {2,}\S", txt) and not txt.startswith("@"):
            items.append(("raw", l)); continue
        m = re.match(r"^(@\w+(?: [\w.,]+)?) ?(.*)$", txt) if txt.startswith("@") else None
        b = re.match(r"^(\s*)([*-]|\d+\.) (.*)$", txt)
        if m and m.group(1).split()[0] in ("@param", "@return", "@returns", "@description", "@details",
                                             "@seealso", "@section", "@note", "@format", "@source", "@inheritParams"):
            items.append(["para", pre + " " + m.group(1) + " ", pre + "   ", m.group(2)])
        elif m:
            items.append(("raw", l))
        elif b:
            ind = b.group(1)
            items.append(["para", pre + " " + ind + b.group(2) + " ", pre + " " + ind + " " * (len(b.group(2)) + 1), b.group(3)])
        elif items and items[-1][0] == "para":
            items[-1][3] += " " + txt.strip()
        else:
            items.append(["para", pre + " " + txt[:len(txt) - len(txt.lstrip())], pre + " " + txt[:len(txt) - len(txt.lstrip())], txt.strip()])
    for it in items:
        if it[0] == "raw":
            out.append(it[1])
        else:
            out.extend(wrap(it[3].strip(), it[1], it[2]))
    return out


def comment_block(lines, indent):
    pre = indent + "#"
    texts = [l[len(pre):] for l in lines]
    if all(len(l) <= WIDTH for l in lines):
        return lines
    out = []
    para, para_ind = [], None

    def flush():
        nonlocal para
        if para:
            out.extend(wrap(" ".join(para), pre + para_ind, pre + para_ind))
            para = []

    for l, t in zip(lines, texts):
        if re.match(r"^ ?[=\-]{10,}", t) or re.match(r"^ ?-{10,}.*$", t):
            flush()
            rule = re.match(r"^( ?)([=\-])", t)
            label = re.sub(r"^ ?[=\-]+ ?", "", t).strip()
            line = pre + rule.group(1) + (rule.group(2) * (WIDTH - len(pre) - 1 - (len(label) + 1 if label else 0)))
            out.append(line + (" " + label if label else "")); continue
        stripped = t.strip()
        if not stripped or re.search(r"\S {2,}\S", stripped) or len(l) <= WIDTH and not para:
            flush(); out.append(l); continue
        ind = t[:len(t) - len(t.lstrip())] or " "
        if para and ind != para_ind:
            flush()
        para_ind = ind
        para.append(stripped)
    flush()
    return out


def process(path):
    src = open(path, encoding="utf-8").read().split("\n")
    out, i = [], 0
    while i < len(src):
        l = src[i]
        m = re.match(r"^(\s*)#'", l)
        if m:
            j = i
            while j < len(src) and re.match(r"^" + re.escape(m.group(1)) + r"#'", src[j]):
                j += 1
            out.extend(roxygen_block(src[i:j], m.group(1)))
            i = j; continue
        m = re.match(r"^(\s*)#(?!')", l)
        if m:
            j = i
            while j < len(src) and re.match(r"^" + re.escape(m.group(1)) + r"#(?!')", src[j]):
                j += 1
            out.extend(comment_block(src[i:j], m.group(1)))
            i = j; continue
        # a comment at the end of a line of code
        if len(l) > WIDTH:
            c = trailing_comment(l)
            if c is not None:
                code, comment = l[:c].rstrip(), l[c:].lstrip("#").strip()
                ind = l[:len(l) - len(l.lstrip())]
                out.extend(wrap(comment, ind + "# ", ind + "# "))
                out.append(code); i += 1; continue
        out.append(l); i += 1
    open(path, "w", encoding="utf-8").write("\n".join(out))


def trailing_comment(l):
    """The position of a # that starts a comment after code, outside strings; None if there is none."""
    q = None
    k = 0
    while k < len(l):
        ch = l[k]
        if q:
            if ch == "\\": k += 2; continue
            if ch == q: q = None
        elif ch in "\"'`": q = ch
        elif ch == "#":
            return k if l[:k].strip() else None
        k += 1
    return None


if __name__ == "__main__" and (len(sys.argv) < 2 or sys.argv[1] != "--examples"):
    for p in sys.argv[1:]:
        process(p)


def format_examples(path, air):
    """Formats the R code of the @examples sections of the roxygen blocks with Air (the macros \\donttest{ and } stay
    on lines of their own)."""
    import subprocess, tempfile, os
    src = open(path, encoding="utf-8").read().split("\n")
    out, i = [], 0
    while i < len(src):
        out.append(src[i])
        if re.match(r"^#' @examples\s*$", src[i]):
            j = i + 1
            while j < len(src) and src[j].startswith("#'") and not re.match(r"^#' @", src[j]):
                j += 1
            code = [l[3:] if l.startswith("#' ") else l[2:] for l in src[i + 1:j]]
            pieces, cur, open_macros, depth = [], [], 0, 0
            for c in code:
                bare = re.sub(r'"(\\.|[^"\\])*"', '""', c)
                if re.match(r"^\\(donttest|dontrun)\{\s*$", c):
                    if cur: pieces.append(("code", cur)); cur = []
                    pieces.append(("macro", c)); open_macros += 1; continue
                if c.strip() == "}" and open_macros and depth == 0:
                    if cur: pieces.append(("code", cur)); cur = []
                    pieces.append(("macro", c)); open_macros -= 1; continue
                depth += bare.count("{") - bare.count("}")
                cur.append(c)
            if cur: pieces.append(("code", cur))
            for kind, p in pieces:
                if kind == "macro":
                    out.append("#' " + p); continue
                with tempfile.NamedTemporaryFile("w", suffix=".R", delete=False) as f:
                    f.write("\n".join(p) + "\n")
                r = subprocess.run([air, "format", f.name], capture_output=True)
                formatted = open(f.name).read().rstrip("\n").split("\n") if r.returncode == 0 else p
                if r.returncode != 0: print("not formatted (Air could not parse it):", path, p[:2])
                os.unlink(f.name)
                out.extend(("#' " + l).rstrip() for l in formatted)
            i = j; continue
        i += 1
    open(path, "w", encoding="utf-8").write("\n".join(out))


if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[1] == "--examples":
    for p in sys.argv[3:]:
        format_examples(p, sys.argv[2])
