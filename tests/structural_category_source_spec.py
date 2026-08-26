#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STRUCTURAL = ROOT / "src/ReplicatedStorage/MechFramework/Shared/PartDefinitions/Structural.luau"

source = STRUCTURAL.read_text(encoding="utf-8")
part_ids = re.findall(r'\bH\.part\s*\(\s*"([^"]+)"', source)
explicit_structural = re.findall(
    r'\bH\.part\s*\(\s*"[^"]+"\s*,\s*"[^"]+"\s*,\s*"[^"]+"\s*,\s*"Structural"\s*,',
    source,
)

if not part_ids:
    print("FAIL: Structural.luau contains no H.part definitions")
    sys.exit(1)

if len(explicit_structural) != len(part_ids):
    print(
        f"FAIL: every Structural part must pass 'Structural' as the explicit category; "
        f"found {len(explicit_structural)} explicit categories across {len(part_ids)} parts"
    )
    sys.exit(1)

print(f"PASS: {len(part_ids)} Structural parts all pass the explicit category")
