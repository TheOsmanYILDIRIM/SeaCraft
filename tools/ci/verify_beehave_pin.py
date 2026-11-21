#!/usr/bin/env python3
import hashlib
import sys
from pathlib import Path

TAG = "v2.9.3"
COMMIT = "773a5f6dd9b3433cdb8735ab35e9043d4cd60674"
UPSTREAM = "bitbrain/beehave"

EXPECTED = {
    "addons/beehave/LICENSE": "caabbff9de9159885450a88d83a03291c1f240ba",
    "addons/beehave/blackboard.gd": "ee5777f71fb7aa52ab33ff83b7cc69ca8ab5aabf",
    "addons/beehave/debug/debugger_messages.gd": "3eddb09d6221a6b6ef4078a334b321fdce5cb1f6",
    "addons/beehave/debug/global_debugger.gd": "8d344e307056a71cba21d26109f4c682895751e3",
    "addons/beehave/metrics/beehave_global_metrics.gd": "f019cb05b455e22b056b279e837a3900fc6fa1e6",
    "addons/beehave/nodes/beehave_node.gd": "aff1ae55a1708b0e9efa535ed09d037f3de73358",
    "addons/beehave/nodes/beehave_tree.gd": "d73caaf21d5c80c096d639c06a36406dafb90e66",
    "addons/beehave/nodes/leaves/leaf.gd": "9c65fffb1b0eaba89498f3fecd0ec60d1a2fbf02",
    "addons/beehave/nodes/leaves/action.gd": "003bdb4ee241b8d423ded82312dc14e5ba85e520",
    "addons/beehave/nodes/leaves/condition.gd": "55ec6f9c0257a511316e6f73b42231d9bf060d12",
    "addons/beehave/icons/tree.svg": "6c85ea11d08a830a8f75079a5045af5ea238365b",
    "addons/beehave/icons/category_leaf.svg": "1482fe63a41a8b6bfc33bb6907e7e864aeaf8239",
    "addons/beehave/icons/action.svg": "3916c89825e250d2fca333b40ded2226b8e7809c",
    "addons/beehave/icons/condition.svg": "37b2c7a73dbed016096cad07a2429ae6c0df0885",
    "addons/beehave/icons/blackboard.svg": "e4948a5b47d119b0ab50827edd0da807f58bad77",
}

def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()

def fail(msg: str) -> None:
    print(f"Beehave pin verifier failed: {msg}", file=sys.stderr)
    raise SystemExit(1)

def main() -> None:
    for path, expected_sha in EXPECTED.items():
        p = Path(path)
        if not p.is_file():
            fail(f"missing pinned runtime file: {path}")
        actual = git_blob_sha(p.read_bytes())
        if actual != expected_sha:
            fail(f"upstream blob mismatch for {path}: {actual} != {expected_sha}")
    project = Path("project.godot").read_text(encoding="utf-8")
    if "[autoload]" in project or "BeehaveGlobalMetrics" in project or "BeehaveGlobalDebugger" in project:
        fail("Beehave must stay detached/manual; project autoloads are not allowed")
    presets = Path("export_presets.cfg").read_text(encoding="utf-8")
    if 'exclude_filter="tests/**,tools/**,addons/**"' in presets:
        fail("export still strips all addons")
    if presets.count('exclude_filter="tests/**,tools/**,addons/gut/**"') != 2:
        fail("exports must keep Beehave while excluding GUT")
    runner = Path("src/simulation/ai/ai_bt_runner.gd").read_text(encoding="utf-8")
    if "BeehaveTree.ProcessThread.MANUAL" not in runner or "_tree.tick()" not in runner:
        fail("SeaCraft runner is not manual Beehave execution")
    if "not _tree.is_inside_tree()" not in runner or "actor.add_child(_tree)" in runner:
        fail("Beehave runtime tree must remain detached from SceneTree")
    print(
        f"AI01_BEEHAVE_PIN_OK tag={TAG} commit={COMMIT} upstream={UPSTREAM} runtime_files={len(EXPECTED)}"
    )

if __name__ == "__main__":
    main()
