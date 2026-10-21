"""Formats the R chunks of R Markdown files with Air (the tidyverse style), leaving the text alone.

    python3 tools/format_chunks.py path/to/air vignettes/*.Rmd.orig README.Rmd
"""
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wrap_comments  # noqa: E402  (re-flows the comments, as for the R files)

air = sys.argv[1]
CHUNK = re.compile(r"(```\{r[^\n]*\}\n)(.*?)(\n```)", re.S)
for path in sys.argv[2:]:
    text = open(path, encoding="utf-8").read()

    def fmt(m):
        with tempfile.NamedTemporaryFile("w", suffix=".R", delete=False) as f:
            f.write(m.group(2) + "\n")
        wrap_comments.process(f.name)
        r = subprocess.run([air, "format", f.name], capture_output=True)
        code = open(f.name).read().rstrip("\n") if r.returncode == 0 else m.group(2)
        os.unlink(f.name)
        if r.returncode != 0:
            print(path, ": chunk left as it was:", m.group(1).strip())
        return m.group(1) + code + m.group(3)

    open(path, "w", encoding="utf-8").write(CHUNK.sub(fmt, text))
