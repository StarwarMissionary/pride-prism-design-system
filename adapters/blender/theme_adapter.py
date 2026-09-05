"""Color-only Blender 4.5 adapter. Stage first; commit is a separate explicit action.

Ordinary Python runs the stage/commit commands. Blender runs only the two private
worker commands, with CONFIG redirected to a copy of the existing preferences.
No user startup.blend, project, scene, or application resource is opened/written.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
import uuid


WIDGETS = (
    "wcol_regular", "wcol_tool", "wcol_toolbar_item", "wcol_radio", "wcol_text",
    "wcol_option", "wcol_toggle", "wcol_num", "wcol_numslider", "wcol_box",
    "wcol_menu", "wcol_pulldown", "wcol_menu_back", "wcol_pie_menu",
    "wcol_tooltip", "wcol_menu_item", "wcol_scroll", "wcol_progress",
    "wcol_list_item", "wcol_tab",
)
# Explicit allowlist. Deliberately exclude wcol_state, axes, gizmos, icons,
# view_3d, nodes/wires, material/collection/object colors, and all ThemeStyle.
COLOR_MAP = {
    f"user_interface.{widget}.{field}": token
    for widget in WIDGETS
    for field, token in {
        "outline": "borderSubtle", "inner": "surfaceRaised",
        "inner_sel": "selection", "item": "accent",
        "text": "foreground", "text_sel": "selectionText",
    }.items()
}
COLOR_MAP.update({
    "user_interface.editor_border": "borderSubtle",
    "user_interface.editor_outline": "borderSubtle",
    "user_interface.editor_outline_active": "focus",
    "user_interface.widget_text_cursor": "focus",
})
for _editor in ("preferences", "properties", "outliner", "topbar", "statusbar"):
    for _field, _token in {
        "back": "surface", "title": "foreground", "text": "foreground",
        "text_hi": "foreground", "header": "surfaceRaised",
        "header_text": "foreground", "header_text_hi": "foreground",
        "button": "surfaceMuted", "button_title": "foreground",
        "button_text": "foregroundMuted", "button_text_hi": "foreground",
        "navigation_bar": "surface", "execution_buts": "surfaceRaised",
        "tab_active": "selection", "tab_inactive": "surfaceRaised",
        "tab_back": "surface", "tab_outline": "borderSubtle",
        "panelcolors.header": "surfaceRaised", "panelcolors.back": "surface",
        "panelcolors.sub_back": "surfaceMuted",
    }.items():
        COLOR_MAP[f"{_editor}.space.{_field}"] = _token
SCHEMA_VERSION = 1


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path: Path):
    with path.open(encoding="utf-8-sig") as stream:
        return json.load(stream)


def write_json(path: Path, value) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write("\n")


def read_theme(path: Path) -> dict:
    theme = read_json(path)
    colors = theme.get("colors", {})
    for token in set(COLOR_MAP.values()):
        if not isinstance(colors.get(token), str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", colors[token]):
            raise ValueError(f"colors.{token} must be a six-digit #RRGGBB color")
    return theme


def color_vector(hex_color: str, original) -> tuple:
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", hex_color):
        raise ValueError("Expected #RRGGBB")
    if len(original) not in (3, 4):
        raise ValueError("Expected an RGB/RGBA theme color")
    rgb = tuple(int(hex_color[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    # Keep opacity exactly: color changes must not make invisible borders opaque.
    return rgb + ((original[3],) if len(original) == 4 else ())


def target_property(root, path: str):
    pieces = path.split(".")
    parent = root
    for name in pieces[:-1]:
        parent = getattr(parent, name)  # A changed/missing API fails closed.
    return parent, pieces[-1]


def apply_colors(theme, colors: dict) -> list[str]:
    pending = []
    for path, token in COLOR_MAP.items():
        parent, name = target_property(theme, path)
        pending.append((path, parent, name, color_vector(colors[token], getattr(parent, name))))
    # Validate every target before changing the first field.
    for _path, parent, name, value in pending:
        setattr(parent, name, value)
    return [path for path, _parent, _name, _value in pending]


def snapshot_rna(value) -> dict:
    """Theme fields only; never inspect add-on preferences or other user data."""
    result = {}
    for prop in value.bl_rna.properties:
        name = prop.identifier
        if name == "rna_type":
            continue
        current = getattr(value, name)
        if prop.type == "POINTER":
            result[name] = snapshot_rna(current) if current is not None else None
        elif prop.type == "COLLECTION":
            result[name] = [snapshot_rna(item) for item in current]
        elif not prop.is_readonly:
            if getattr(prop, "array_length", 0) > 0:
                result[name] = [round(item, 6) if isinstance(item, float) else item for item in current]
            elif isinstance(current, float):
                result[name] = round(current, 6)
            elif isinstance(current, set):
                result[name] = sorted(current)
            elif current is None or isinstance(current, (str, bool, int)):
                result[name] = current
            else:
                raise TypeError(f"Unsupported theme field: {name}")
    return result


def theme_snapshot(preferences) -> dict:
    return {
        "Theme": snapshot_rna(preferences.themes[0]),
        "ThemeStyle": snapshot_rna(preferences.ui_styles[0]),
    }


def expected_snapshot(before: dict, colors: dict) -> dict:
    expected = json.loads(json.dumps(before))
    for path, token in COLOR_MAP.items():
        parts = path.split(".")
        node = expected["Theme"]
        for part in parts[:-1]:
            node = node[part]
        node[parts[-1]] = [round(item, 6) for item in color_vector(colors[token], node[parts[-1]])]
    return expected


def assert_isolated_config(actual: Path, stage_dir: Path, live_dir: Path) -> Path:
    actual = actual.resolve()
    expected = (stage_dir / "config").resolve()
    if actual != expected or actual == live_dir.resolve():
        raise RuntimeError("Refusing to save: Blender CONFIG is not the isolated staging directory")
    if (actual / "startup.blend").exists():
        raise RuntimeError("Staging must not contain a user startup.blend")
    if not (actual / "userpref.blend").is_file():
        raise RuntimeError("Existing copied user preferences are required; factory preferences cannot be saved")
    return actual


def blender_worker(mode: str, stage_dir: Path) -> None:
    import bpy
    import rna_xml

    stage_dir = stage_dir.resolve()
    manifest = read_json(stage_dir / "manifest.json")
    if manifest["schema_version"] != SCHEMA_VERSION or tuple(bpy.app.version[:2]) != (4, 5):
        raise RuntimeError("This adapter is validated against the Blender 4.5 API only")
    actual_config = Path(bpy.utils.user_resource("CONFIG"))
    config_dir = assert_isolated_config(actual_config, stage_dir, Path(manifest["live_config"]))
    if manifest["adapter_sha256"] != sha256(Path(__file__)):
        raise RuntimeError("Adapter changed after staging began")
    if manifest["theme_json_sha256"] != sha256(stage_dir / "theme.json"):
        raise RuntimeError("Theme contract changed after staging began")
    theme = read_theme(stage_dir / "theme.json")
    preferences = bpy.context.preferences
    if mode == "blender-stage":
        if sha256(config_dir / "userpref.blend") != manifest["source_preferences_sha256"]:
            raise RuntimeError("Copied preferences no longer match the source backup")
        before = theme_snapshot(preferences)
        preset_map = bpy.types.USERPREF_MT_interface_theme_presets.preset_xml_map
        if tuple(preset_map) != (("preferences.themes[0]", "Theme"), ("preferences.ui_styles[0]", "ThemeStyle")):
            raise RuntimeError("Unexpected Blender theme export map")
        rna_xml.xml_file_write(bpy.context, str(stage_dir / "before-theme.xml"), preset_map)
        write_json(stage_dir / "before-theme.json", before)
        paths = apply_colors(preferences.themes[0], theme["colors"])
        expected = expected_snapshot(before, theme["colors"])
        if theme_snapshot(preferences) != expected:
            raise RuntimeError("Theme read-back changed a non-allowlisted field or did not retain the requested colors")
        rna_xml.xml_file_write(bpy.context, str(stage_dir / "candidate-theme.xml"), preset_map)
        write_json(stage_dir / "expected-theme.json", expected)
        # This writes the cloned CONFIG only. Never run this mode in a live app.
        if bpy.ops.wm.save_userpref() != {"FINISHED"}:
            raise RuntimeError("Blender did not save the staged preferences")
        manifest["blender_version"] = bpy.app.version_string
        manifest["changed_paths"] = paths
        manifest["candidate_preferences_sha256"] = sha256(config_dir / "userpref.blend")
        manifest["candidate_theme_sha256"] = sha256(stage_dir / "candidate-theme.xml")
        manifest["before_theme_sha256"] = sha256(stage_dir / "before-theme.xml")
        write_json(stage_dir / "manifest.json", manifest)
    elif mode == "blender-verify":
        if sha256(config_dir / "userpref.blend") != manifest["candidate_preferences_sha256"]:
            raise RuntimeError("Candidate preferences changed before verification")
        if theme_snapshot(preferences) != read_json(stage_dir / "expected-theme.json"):
            raise RuntimeError("Reloaded candidate did not preserve all non-allowlisted Theme/ThemeStyle fields")
        manifest["validated"] = True
        write_json(stage_dir / "manifest.json", manifest)
    else:
        raise ValueError(mode)


def launch_worker(blender: Path, stage_dir: Path, mode: str) -> None:
    environment = os.environ.copy()
    environment["BLENDER_USER_CONFIG"] = str(stage_dir / "config")
    environment["BLENDER_USER_SCRIPTS"] = str(stage_dir / "scripts")
    environment["BLENDER_USER_EXTENSIONS"] = str(stage_dir / "extensions")
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    # No .blend argument and no copied startup file. Do not use --factory-startup:
    # it bypasses the preferences we must preserve. Installed add-ons referenced
    # by preferences can still initialize; the stage command requires acknowledgment.
    command = [str(blender), "--background", "--disable-autoexec", "--offline-mode",
               "--python-exit-code", "21", "--python", str(Path(__file__).resolve()),
               "--", mode, "--stage-dir", str(stage_dir)]
    with (stage_dir / f"{mode}.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(command, env=environment, cwd=stage_dir, stdout=log,
                                stderr=subprocess.STDOUT, timeout=120,
                                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
    if result.returncode != 0:
        raise RuntimeError(f"{mode} failed ({result.returncode}); no live preferences committed. Review {stage_dir / (mode + '.log')}")


def stage(args) -> dict:
    if not args.allow_preference_addons:
        raise RuntimeError("Stage starts isolated Blender with copied preferences, which may initialize their installed add-ons. Review this and pass --allow-preference-addons explicitly; nothing has been launched.")
    source_config = args.config_dir.resolve()
    source = source_config / "userpref.blend"
    blender = args.blender.resolve()
    if not blender.is_file() or not source.is_file():
        raise FileNotFoundError("An installed Blender executable and existing userpref.blend are required")
    read_theme(args.theme_json)
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ") + "-" + uuid.uuid4().hex
    stage_dir = (args.output_root / run_id).resolve()
    stage_dir.mkdir(parents=True, exist_ok=False)
    for folder in ("config", "backup", "scripts", "extensions"):
        (stage_dir / folder).mkdir()
    source_hash = sha256(source)
    shutil.copy2(source, stage_dir / "backup" / "userpref.blend")
    shutil.copy2(stage_dir / "backup" / "userpref.blend", stage_dir / "config" / "userpref.blend")
    if sha256(stage_dir / "backup" / "userpref.blend") != source_hash or sha256(source) != source_hash:
        raise RuntimeError("Live preferences changed while copying; no Blender launched")
    shutil.copy2(args.theme_json, stage_dir / "theme.json")
    write_json(stage_dir / "manifest.json", {
        "schema_version": SCHEMA_VERSION,
        "live_config": str(source_config),
        "source_preferences_sha256": source_hash,
        "theme_json_sha256": sha256(stage_dir / "theme.json"),
        "adapter_sha256": sha256(Path(__file__)),
        "validated": False,
    })
    launch_worker(blender, stage_dir, "blender-stage")
    launch_worker(blender, stage_dir, "blender-verify")
    manifest = read_json(stage_dir / "manifest.json")
    if not manifest.get("validated") or sha256(stage_dir / "config" / "userpref.blend") != manifest["candidate_preferences_sha256"]:
        raise RuntimeError("Candidate validation failed; live preferences remain untouched")
    return {"stage_dir": str(stage_dir), "validated": True, "live_preferences_changed": False,
            "theme_rollback": str(stage_dir / "before-theme.xml"), "changed_color_fields": len(COLOR_MAP)}


def assert_blender_closed() -> None:
    if os.name != "nt":
        raise RuntimeError("Automatic commit is supported on Windows only")
    result = subprocess.run(["tasklist.exe", "/FI", "IMAGENAME eq blender.exe", "/FO", "CSV", "/NH"],
                            capture_output=True, text=True, check=True,
                            creationflags=subprocess.CREATE_NO_WINDOW, timeout=15)
    if any(row and row[0].casefold() == "blender.exe" for row in csv.reader(result.stdout.splitlines())):
        raise RuntimeError("Blender is running. Close it normally after saving your work; this adapter never closes applications.")


def validate_commit(stage_dir: Path, config_dir: Path) -> dict:
    manifest = read_json(stage_dir / "manifest.json")
    if manifest.get("schema_version") != SCHEMA_VERSION or manifest.get("validated") is not True:
        raise RuntimeError("A successfully staged and independently reloaded candidate is required")
    if config_dir.resolve() != Path(manifest["live_config"]).resolve():
        raise RuntimeError("Commit target does not match the staged preference source")
    checks = {
        config_dir / "userpref.blend": "source_preferences_sha256",
        stage_dir / "backup" / "userpref.blend": "source_preferences_sha256",
        stage_dir / "config" / "userpref.blend": "candidate_preferences_sha256",
        stage_dir / "candidate-theme.xml": "candidate_theme_sha256",
        stage_dir / "before-theme.xml": "before_theme_sha256",
        stage_dir / "theme.json": "theme_json_sha256",
        Path(__file__): "adapter_sha256",
    }
    for path, field in checks.items():
        if sha256(path) != manifest[field]:
            raise RuntimeError(f"Hash mismatch or later edit: {path}. Nothing committed.")
    return manifest


def commit(args) -> dict:
    stage_dir = args.stage_dir.resolve()
    config_dir = args.config_dir.resolve()
    assert_blender_closed()
    manifest = validate_commit(stage_dir, config_dir)
    target = config_dir / "userpref.blend"
    temporary = config_dir / ("userpref.pride-prism-" + uuid.uuid4().hex + ".tmp")
    # Same-directory replacement is atomic. A full original backup already exists.
    with temporary.open("xb") as destination, (stage_dir / "config" / "userpref.blend").open("rb") as source:
        shutil.copyfileobj(source, destination)
        destination.flush()
        os.fsync(destination.fileno())
    assert_blender_closed()
    validate_commit(stage_dir, config_dir)
    os.replace(temporary, target)
    if sha256(target) != manifest["candidate_preferences_sha256"]:
        raise RuntimeError("Commit read-back mismatch. Original backup retained; do not open Blender until reviewed.")
    return {"preferences": str(target), "applies": "next normal Blender launch",
            "theme_rollback": str(stage_dir / "before-theme.xml"),
            "full_preferences_backup": str(stage_dir / "backup" / "userpref.blend")}


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    stage_parser = commands.add_parser("stage", help="Copy preferences, generate UI colors, and verify in a second isolated Blender process")
    stage_parser.add_argument("--theme-json", type=Path, required=True)
    stage_parser.add_argument("--blender", type=Path, required=True)
    stage_parser.add_argument("--config-dir", type=Path, required=True)
    stage_parser.add_argument("--output-root", type=Path, default=Path(os.environ.get("LOCALAPPDATA", ".")) / "PridePrism" / "Blender" / "Staging")
    stage_parser.add_argument("--allow-preference-addons", action="store_true")
    commit_parser = commands.add_parser("commit", help="Apply a validated candidate while Blender is closed")
    commit_parser.add_argument("--stage-dir", type=Path, required=True)
    commit_parser.add_argument("--config-dir", type=Path, required=True)
    for mode in ("blender-stage", "blender-verify"):
        worker = commands.add_parser(mode, help=argparse.SUPPRESS)
        worker.add_argument("--stage-dir", type=Path, required=True)
    args = parser.parse_args(argv)
    if args.command.startswith("blender-"):
        blender_worker(args.command, args.stage_dir)
    else:
        result = stage(args) if args.command == "stage" else commit(args)
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(arguments)
