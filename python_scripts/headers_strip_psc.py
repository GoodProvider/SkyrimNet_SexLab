"""
strip_psc_headers.py

Reads all .psc files from a source directory, strips the internal code from
function/event/getter/setter bodies, and writes the results to a destination
directory.

Usage:
  python strip_psc_headers.py [-s SOURCE] [-d DESTINATION]

What is PRESERVED:
  - Scriptname, import, variable declarations
  - Auto property declarations
  - Property blocks (structure preserved)
  - All function/event/getter/setter signature lines
  - All End* keywords
  - Comments at any level

What is REMOVED:
  - Lines inside function/event/getter/setter bodies
"""

import argparse
import os
import re
import glob

_SCRIPT_DIR = os.path.dirname(__file__)
_DEFAULT_SRC = os.path.join(_SCRIPT_DIR, '..', 'Scripts', 'Source')
_DEFAULT_DST = os.path.join(_SCRIPT_DIR, '..', 'Headers', 'SkyrimNet_SexLab')

# State constants
NORMAL = 'NORMAL'
IN_FUNCTION = 'IN_FUNCTION'
IN_PROPERTY = 'IN_PROPERTY'
IN_PROP_FUNCTION = 'IN_PROP_FUNCTION'

# Patterns (case-insensitive)
RE_FUNCTION = re.compile(r'^\s*(?:\w+\s+)?Function\s+\w+', re.IGNORECASE)
RE_EVENT = re.compile(r'^\s*Event\s+\w+', re.IGNORECASE)
RE_END_FUNCTION = re.compile(r'^\s*EndFunction\b', re.IGNORECASE)
RE_END_EVENT = re.compile(r'^\s*EndEvent\b', re.IGNORECASE)
RE_PROPERTY_BLOCK = re.compile(r'\bProperty\s+\w+', re.IGNORECASE)
RE_AUTO = re.compile(r'\bAuto\b', re.IGNORECASE)
RE_END_PROPERTY = re.compile(r'^\s*EndProperty\b', re.IGNORECASE)


def strip_file(src_path):
    with open(src_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    out = []
    state = NORMAL

    for line in lines:
        stripped = line.rstrip('\n')

        if state == NORMAL:
            # Property block with getter/setter (no Auto keyword)
            if RE_PROPERTY_BLOCK.search(stripped) and not RE_AUTO.search(stripped):
                out.append(line)
                state = IN_PROPERTY
            # Function signature
            elif RE_FUNCTION.match(stripped):
                out.append(line)
                state = IN_FUNCTION
            # Event signature
            elif RE_EVENT.match(stripped):
                out.append(line)
                state = IN_FUNCTION
            else:
                out.append(line)

        elif state == IN_FUNCTION:
            if RE_END_FUNCTION.match(stripped) or RE_END_EVENT.match(stripped):
                out.append(line)
                state = NORMAL
            # else: skip body lines

        elif state == IN_PROPERTY:
            if RE_END_PROPERTY.match(stripped):
                out.append(line)
                state = NORMAL
            elif RE_FUNCTION.match(stripped):
                # getter or setter signature inside property
                out.append(line)
                state = IN_PROP_FUNCTION
            else:
                out.append(line)

        elif state == IN_PROP_FUNCTION:
            if RE_END_FUNCTION.match(stripped):
                out.append(line)
                state = IN_PROPERTY
            # else: skip body lines

    return ''.join(out)


def main():
    parser = argparse.ArgumentParser(description='Strip Papyrus script bodies to create header stubs.')
    parser.add_argument('-s', '--source', default=_DEFAULT_SRC,
                        help='Directory containing source .psc files (default: Scripts/Source)')
    parser.add_argument('-d', '--destination', default=_DEFAULT_DST,
                        help='Directory to write stripped .psc files (default: Headers/SkyrimNet_SexLab)')
    args = parser.parse_args()

    src_dir = args.source
    out_dir = args.destination

    os.makedirs(out_dir, exist_ok=True)

    src_files = glob.glob(os.path.join(src_dir, '*.psc'))
    if not src_files:
        print(f'No .psc files found in {src_dir}')
        return

    for src_path in sorted(src_files):
        filename = os.path.basename(src_path)
        out_path = os.path.join(out_dir, filename)
        result = strip_file(src_path)
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(result)
        print(f'  {filename}')

    print(f'\nWrote {len(src_files)} files to {os.path.abspath(out_dir)}')


if __name__ == '__main__':
    main()
