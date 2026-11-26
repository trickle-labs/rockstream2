#!/usr/bin/env python3
"""Reject unreviewed workspace dependencies, including future crates."""
import json
import subprocess
import sys

# Explicit allowlist makes each new crate and edge a deliberate review.
ALLOWED = {"w1g-oracle": set()}


def valid(packages):
    names = {p["name"] for p in packages}
    if names != ALLOWED.keys():
        return False
    return all(
        {d["name"] for d in p["dependencies"] if d["name"] in names} <= ALLOWED[p["name"]]
        for p in packages
    )


metadata = json.loads(subprocess.check_output(["cargo", "metadata", "--locked", "--no-deps", "--format-version", "1"]))
packages = metadata["packages"]
if not valid(packages):
    sys.exit("disallowed or unregistered workspace dependency")
# Negative control must fail for the actual parser and policy.
mutant = json.loads(json.dumps(packages))
mutant[0]["dependencies"].append({"name": mutant[0]["name"]})
if valid(mutant):
    sys.exit("dependency negative control was not detected")
print("dependency policy and negative control passed")
