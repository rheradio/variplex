"""Splits the string literals that make a line of R code longer than 80 columns into paste0() of shorter pieces (the
value is the same), so that Air can lay the code out within 80 columns.

    python3 tools/split_strings.py R/*.R tests/testthat/*.R tools/*.R ; air format R tests tools
"""
import re
import sys

WIDTH = 80
LIT = re.compile(r'"(?:[^"\\]|\\.)*"' + r"|'(?:[^'\\]|\\.)*'")


def code_part(line):
    """The line without a trailing comment; None when the line has a string that does not end on it."""
    q, k = None, 0
    while k < len(line):
        c = line[k]
        if q:
            if c == "\\": k += 2; continue
            if c == q: q = None
        elif c in "\"'`": q = c
        elif c == "#": return line[:k]
        k += 1
    return None if q else line


def pieces(body, size):
    """Cuts the text between the quotes into pieces of at most `size` characters, after a space when it can, never
    inside an escape sequence."""
    out, cur = [], ""
    tokens = re.findall(r"\\.|[^\\]", body)
    words, w = [], ""
    for t in tokens:
        w += t
        if t == " ":
            words.append(w); w = ""
    if w: words.append(w)
    for word in words:
        if len(cur) + len(word) > size and cur:
            out.append(cur); cur = ""
        while len(word) > size:                      # a very long word: cut it between tokens
            toks = re.findall(r"\\.|[^\\]", word); part = ""
            while toks and len(part) + len(toks[0]) <= size:
                part += toks.pop(0)
            out.append(part); word = "".join(toks)
        cur += word
    if cur: out.append(cur)
    return out


def split_line(line):
    code = code_part(line)
    if code is None or len(line) <= WIDTH or line.lstrip().startswith("#"):
        return [line]
    lits = [m for m in LIT.finditer(code)]
    if not lits:
        return [line]
    m = max(lits, key=lambda m: len(m.group(0)))
    if len(m.group(0)) < 20:
        return [line]
    ind = line[:len(line) - len(line.lstrip())]
    q = m.group(0)[0]
    size = max(20, WIDTH - len(ind) - 6)
    parts = pieces(m.group(0)[1:-1], size)
    if len(parts) < 2:
        return [line]
    inner = (",\n" + ind + "  ").join(q + p + q for p in parts)
    return [line[:m.start()] + "paste0(\n" + ind + "  " + inner + "\n" + ind + ")" + line[m.end():]]


for path in sys.argv[1:]:
    src = open(path, encoding="utf-8").read().split("\n")
    out = []
    for l in src:
        out.extend(split_line(l))
    open(path, "w", encoding="utf-8").write("\n".join(out))
