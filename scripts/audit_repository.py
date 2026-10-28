"""Local source/asset release guardrails; never contacts a live service."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

root = Path(__file__).resolve().parent.parent
pubspec = (root / "pubspec.yaml").read_text()
assets = re.findall(r"^    - (app/assets/[^\n]+)$", pubspec, re.M)
assert assets and "assets/design_references/" not in pubspec
for asset in assets:
    assert (root / asset).is_file(), asset
manifest = json.loads((root / "app/assets/illustrations/manifest.json").read_text())
for item in manifest:
    path = root / "app/assets/illustrations" / item["file"]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"], path
    assert path.read_bytes()[25] in (4, 6), f"PNG must have alpha: {path}"
    assert path.with_suffix(".prompt.txt").is_file(), path
print(f"PASS: {len(manifest)} original art hashes/alpha/prompts; {len(assets)} explicit bundled assets; references excluded")

tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
secret_patterns = [r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", r"ghp_[A-Za-z0-9]{30,}", r"sk-proj-[A-Za-z0-9_-]{40,}", r'"type"\s*:\s*"service_account"']
for name in filter(None, tracked):
    path = root / name
    if path.suffix.lower() in (".png", ".webp", ".jpg", ".jar"):
        continue
    contents = path.read_text(errors="replace")
    for pattern in secret_patterns:
        # The scanner source contains the patterns themselves, not credentials.
        assert not re.search(pattern, contents), f"Potential credential in {name}"
    assert not name.endswith((".jks", ".keystore", "key.properties", "local.properties")), name
print("PASS: tracked source credential and machine-config guardrails")

features = (root / "docs/product/FEATURES.md").read_text()
p0 = re.findall(r"^\| (\w\d+) \|[^\n]+\| P0 \|", features, re.M)
mapping = (root / "docs/roadmap/TRACEABILITY.md").read_text().split("## P0 release gate mapping")[1]
for feature in p0:
    rows = [line for line in mapping.splitlines() if line.startswith(f"| {feature} |")]
    assert len(rows) == 1 and all(value in rows[0] for value in ["F", "S", "M"]), feature
print(f"PASS: {len(p0)} P0 requirements retain flow/screen/milestone/test mappings")
