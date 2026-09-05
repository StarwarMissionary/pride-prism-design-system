"""Pure unit tests: no Blender launch, registry access, or live preference access."""

import copy
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import theme_adapter as adapter


def sample_colors():
    return {token: "#E866AF" for token in set(adapter.COLOR_MAP.values())}


def theme_tree():
    root = SimpleNamespace()
    for path in adapter.COLOR_MAP:
        node = root
        for name in path.split(".")[:-1]:
            if not hasattr(node, name):
                setattr(node, name, SimpleNamespace())
            node = getattr(node, name)
        setattr(node, path.split(".")[-1], (0.1, 0.2, 0.3, 0.37))
    root.user_interface.wcol_regular.roundness = 0.28
    root.user_interface.wcol_regular.show_shaded = True
    root.user_interface.axis_x = (1.0, 0.0, 0.0)
    root.user_interface.wcol_state = SimpleNamespace(inner_anim=(0.2, 0.4, 0.6))
    root.view_3d = SimpleNamespace(back=(0.02, 0.02, 0.02), wire=(1, 1, 1), vertex_size=3)
    root.node_editor = SimpleNamespace(wire=(0.5, 0.3, 0.9))
    root.collection_color = [(1.0, 0.0, 1.0)]
    return root


def dictionary(value):
    if isinstance(value, SimpleNamespace):
        return {name: dictionary(item) for name, item in vars(value).items()}
    if isinstance(value, (tuple, list)):
        return [dictionary(item) for item in value]
    return value


class ColorTests(unittest.TestCase):
    def test_channel_order_and_alpha_preserved(self):
        self.assertEqual(adapter.color_vector("#FF0080", (0, 0, 0)), (1.0, 0.0, 128 / 255))
        self.assertEqual(adapter.color_vector("#e866af", (0, 0, 0, 0.0))[-1], 0.0)
        self.assertEqual(adapter.color_vector("#E866AF", (0, 0, 0, 0.37))[-1], 0.37)

    def test_invalid_color_and_vector_rejected(self):
        for invalid in ("pink", "#123", "#12345678", "#GGGGGG", " #123456"):
            with self.assertRaises(ValueError):
                adapter.color_vector(invalid, (0, 0, 0))
        with self.assertRaises(ValueError):
            adapter.color_vector("#123456", (0, 0))

    def test_allowlist_excludes_semantic_and_viewport_fields(self):
        allowed_roots = {"user_interface", "preferences", "properties", "outliner", "topbar", "statusbar"}
        for path in adapter.COLOR_MAP:
            self.assertIn(path.split(".")[0], allowed_roots)
            self.assertNotIn("wcol_state", path)
            self.assertNotRegex(path, r"roundness|font|points|vertex|gizmo|axis|wire|material")

    def test_color_apply_preserves_alpha_metrics_and_scene_colors(self):
        theme = theme_tree()
        before = copy.deepcopy(theme)
        adapter.apply_colors(theme, sample_colors())
        self.assertEqual(theme.view_3d, before.view_3d)
        self.assertEqual(theme.node_editor, before.node_editor)
        self.assertEqual(theme.collection_color, before.collection_color)
        self.assertEqual(theme.user_interface.axis_x, before.user_interface.axis_x)
        self.assertEqual(theme.user_interface.wcol_state, before.user_interface.wcol_state)
        self.assertEqual(theme.user_interface.wcol_regular.roundness, 0.28)
        self.assertTrue(theme.user_interface.wcol_regular.show_shaded)
        self.assertEqual(theme.user_interface.wcol_regular.inner[-1], 0.37)
        self.assertEqual(theme.user_interface.wcol_regular.inner[:3], adapter.color_vector("#E866AF", (0, 0, 0)))

    def test_missing_api_fails_before_first_write(self):
        theme = theme_tree()
        before = copy.deepcopy(theme.user_interface.wcol_regular.inner)
        del theme.statusbar.space.panelcolors.sub_back
        with self.assertRaises(AttributeError):
            adapter.apply_colors(theme, sample_colors())
        self.assertEqual(theme.user_interface.wcol_regular.inner, before)

    def test_expected_snapshot_preserves_theme_style_and_extra_fields(self):
        before = {"Theme": dictionary(theme_tree()), "ThemeStyle": {"widget": {"points": 11, "shadow": 1}}}
        original = copy.deepcopy(before)
        expected = adapter.expected_snapshot(before, sample_colors())
        self.assertEqual(before, original)
        self.assertEqual(expected["ThemeStyle"], original["ThemeStyle"])
        self.assertEqual(expected["Theme"]["view_3d"], original["Theme"]["view_3d"])
        self.assertEqual(expected["Theme"]["user_interface"]["wcol_regular"]["roundness"], 0.28)

    def test_snapshot_accepts_scalar_rna_without_array_metadata(self):
        properties = [
            SimpleNamespace(identifier="filepath", type="STRING", is_readonly=False),
            SimpleNamespace(identifier="roundness", type="FLOAT", is_readonly=False),
            SimpleNamespace(identifier="inner", type="FLOAT", is_readonly=False, array_length=3),
        ]
        value = SimpleNamespace(bl_rna=SimpleNamespace(properties=properties),
                                filepath="preset.xml", roundness=0.28, inner=(0.1, 0.2, 0.3))
        self.assertEqual(adapter.snapshot_rna(value), {
            "filepath": "preset.xml", "roundness": 0.28, "inner": [0.1, 0.2, 0.3]})


class IsolatedFixtureTests(unittest.TestCase):
    def setUp(self):
        # All fixtures stay within this adapter's owned directory and are removed.
        self.temporary = tempfile.TemporaryDirectory(prefix=".adapter-test-", dir=Path(__file__).parent)
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def test_contract_validation(self):
        path = self.root / "theme.json"
        adapter.write_json(path, {"colors": sample_colors()})
        self.assertEqual(adapter.read_theme(path)["colors"], sample_colors())
        adapter.write_json(path, {"colors": {}})
        with self.assertRaises(ValueError):
            adapter.read_theme(path)

    def test_isolated_config_refuses_live_or_factory_preferences(self):
        stage = self.root / "stage"
        config = stage / "config"
        config.mkdir(parents=True)
        live = self.root / "live"
        live.mkdir()
        with self.assertRaises(RuntimeError):
            adapter.assert_isolated_config(config, stage, live)
        (config / "userpref.blend").write_bytes(b"fixture preferences")
        self.assertEqual(adapter.assert_isolated_config(config, stage, live), config.resolve())
        with self.assertRaises(RuntimeError):
            adapter.assert_isolated_config(live, stage, live)
        (config / "startup.blend").write_bytes(b"fixture startup marker")
        with self.assertRaises(RuntimeError):
            adapter.assert_isolated_config(config, stage, live)

    def test_stage_requires_explicit_addon_acknowledgment(self):
        with patch.object(adapter, "launch_worker") as launch:
            with self.assertRaises(RuntimeError):
                adapter.stage(SimpleNamespace(allow_preference_addons=False))
            launch.assert_not_called()

    def commit_fixture(self):
        stage = self.root / "stage"
        live = self.root / "live"
        for folder in (stage / "config", stage / "backup", live):
            folder.mkdir(parents=True, exist_ok=True)
        (live / "userpref.blend").write_bytes(b"original fixture")
        (stage / "backup" / "userpref.blend").write_bytes(b"original fixture")
        (stage / "config" / "userpref.blend").write_bytes(b"candidate fixture")
        for name in ("candidate-theme.xml", "before-theme.xml", "theme.json"):
            (stage / name).write_text("fixture " + name, encoding="utf-8")
        manifest = {
            "schema_version": adapter.SCHEMA_VERSION, "validated": True,
            "live_config": str(live.resolve()),
            "source_preferences_sha256": adapter.sha256(live / "userpref.blend"),
            "candidate_preferences_sha256": adapter.sha256(stage / "config" / "userpref.blend"),
            "candidate_theme_sha256": adapter.sha256(stage / "candidate-theme.xml"),
            "before_theme_sha256": adapter.sha256(stage / "before-theme.xml"),
            "theme_json_sha256": adapter.sha256(stage / "theme.json"),
            "adapter_sha256": adapter.sha256(Path(adapter.__file__)),
        }
        adapter.write_json(stage / "manifest.json", manifest)
        return stage, live, manifest

    def test_commit_validation_accepts_consistent_fixture_without_writing(self):
        stage, live, manifest = self.commit_fixture()
        self.assertEqual(adapter.validate_commit(stage, live), manifest)
        self.assertEqual((live / "userpref.blend").read_bytes(), b"original fixture")

    def test_commit_validation_rejects_later_live_edits(self):
        stage, live, _manifest = self.commit_fixture()
        (live / "userpref.blend").write_bytes(b"later user edit")
        with self.assertRaises(RuntimeError):
            adapter.validate_commit(stage, live)
        self.assertEqual((live / "userpref.blend").read_bytes(), b"later user edit")

    def test_commit_validation_rejects_unverified_candidate(self):
        stage, live, manifest = self.commit_fixture()
        manifest["validated"] = False
        adapter.write_json(stage / "manifest.json", manifest)
        with self.assertRaises(RuntimeError):
            adapter.validate_commit(stage, live)

    def test_commit_validation_rejects_altered_candidate_or_wrong_target(self):
        stage, live, _manifest = self.commit_fixture()
        with self.assertRaises(RuntimeError):
            adapter.validate_commit(stage, self.root / "wrong")
        (stage / "candidate-theme.xml").write_text("changed", encoding="utf-8")
        with self.assertRaises(RuntimeError):
            adapter.validate_commit(stage, live)


if __name__ == "__main__":
    unittest.main()
