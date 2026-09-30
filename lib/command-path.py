#!/usr/bin/env python3
"""Generate an idempotent, explicitly requested shell PATH candidate."""
from pathlib import Path
import sys

BEGIN = '# BEGIN CODEX BOOTSTRAP PATH'
END = '# END CODEX BOOTSTRAP PATH'
mode, file, assignment = sys.argv[1:]
p = Path(file)
text = p.read_text() if p.exists() else ''
if text.count(BEGIN) != text.count(END) or text.count(BEGIN) > 1:
    sys.exit('bootstrap: malformed PATH markers; reconcile the shell file first')
if BEGIN in text:
    if text.index(END) < text.index(BEGIN):
        sys.exit('bootstrap: reversed PATH markers')
    text = text[:text.index(BEGIN)] + text[text.index(END)+len(END):].lstrip('\n')
if mode == 'install-command':
    text = text.rstrip() + '\n\n' + BEGIN + '\n' + assignment + '\n' + END + '\n'
sys.stdout.write(text)
