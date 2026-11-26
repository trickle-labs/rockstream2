#!/usr/bin/env python3
"""Reject unreviewed workspace dependencies, including transitive paths."""
import copy
import json
import subprocess
import sys

# Each workspace crate lists every workspace crate it may reach, directly or not.
ALLOWED = {"w1g-oracle": set(), "w1g-kernel": {"w1g-oracle"}}


def valid(packages, nodes, workspace, allowed):
    names = {p["id"]: p["name"] for p in packages}
    if {names[i] for i in workspace} != allowed.keys():
        return False
    edges = {node["id"]: node["dependencies"] for node in nodes}
    if not set(workspace) <= edges.keys():
        return False
    for start in workspace:
        seen = set()
        pending = list(edges[start])
        while pending:
            node = pending.pop()
            if node in seen:
                continue
            seen.add(node)
            if node not in edges:
                return False
            pending.extend(edges[node])
        if {names[i] for i in seen if i in workspace} - allowed[names[start]]:
            return False
    return True


metadata = json.loads(subprocess.check_output(["cargo", "metadata", "--locked", "--format-version", "1"]))
packages = metadata["packages"]
nodes = metadata["resolve"]["nodes"]
workspace = set(metadata["workspace_members"])
if not valid(packages, nodes, workspace, ALLOWED):
    sys.exit("disallowed or unregistered workspace dependency")
# Exercise a prohibited edge and a path hidden behind an external dependency.
synthetic_packages = [{"id": "a", "name": "a"}, {"id": "b", "name": "b"}, {"id": "x", "name": "external"}]
synthetic_nodes = [{"id": "a", "dependencies": ["b"]}, {"id": "b", "dependencies": []}, {"id": "x", "dependencies": []}]
synthetic_allowed = {"a": set(), "b": set()}
if valid(synthetic_packages, synthetic_nodes, {"a", "b"}, synthetic_allowed):
    sys.exit("direct dependency negative control was not detected")
mutant = copy.deepcopy(synthetic_nodes)
mutant[0]["dependencies"] = ["x"]
mutant[2]["dependencies"] = ["b"]
if valid(synthetic_packages, mutant, {"a", "b"}, synthetic_allowed):
    sys.exit("transitive dependency negative control was not detected")
print("dependency policy and direct/transitive negative controls passed")
