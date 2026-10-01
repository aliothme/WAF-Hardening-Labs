#!/usr/bin/env bash
# Run on a Linux host with curl, python3, and sha256sum. Downloads several GB.
set -Eeuo pipefail
[[ ${1:-} != --help ]] || { echo 'Usage: bash scripts/download-isos.sh [DOWNLOAD_DIRECTORY]'; exit 0; }
DEST=${1:-downloads}
mkdir -p "$DEST/ubuntu" "$DEST/kali"
download() {
  local kind=$1 base=$2 pattern=$3 dir="$DEST/$1" file
  curl --fail --location --show-error "$base" -o "$dir/index.html"
  file=$(python3 - "$dir/index.html" "$pattern" <<'PY'
import re,sys
from pathlib import Path
names=set(re.findall(sys.argv[2],Path(sys.argv[1]).read_text()))
if not names:raise SystemExit('No matching ISO in official directory. Check its download page.')
print(sorted(names,key=lambda s:[int(v) for v in re.findall(r'\d+',s)])[-1])
PY
)
  printf 'Downloading %s: %s\n' "$kind" "$file"
  curl --fail --location --show-error --continue-at - "$base$file" -o "$dir/$file"
  curl --fail --location --show-error "${base}SHA256SUMS" -o "$dir/SHA256SUMS"
  curl --fail --location --show-error "${base}SHA256SUMS.gpg" -o "$dir/SHA256SUMS.gpg"
  python3 - "$dir/SHA256SUMS" "$file" >"$dir/selected.sha256" <<'PY'
import sys
from pathlib import Path
lines=[line for line in Path(sys.argv[1]).read_text().splitlines() if line.split() and line.split()[-1].lstrip('*')==sys.argv[2]]
if len(lines)!=1:raise SystemExit('Expected exactly one checksum for the selected ISO.')
print(lines[0])
PY
  (cd "$dir" && sha256sum --check selected.sha256)
}
download ubuntu https://releases.ubuntu.com/noble/ 'ubuntu-24\.04(?:\.\d+)?-live-server-amd64\.iso'
download kali https://cdimage.kali.org/current/ 'kali-linux-\d{4}\.\d+[a-z]?-installer-amd64\.iso'
echo 'Checksums checked against HTTPS downloads. Also verify the signed checksum files using the official signing-key instructions in docs/01-virtual-machines.md.'
