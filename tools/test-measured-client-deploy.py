"""Exercise packaging/backup/refusal/rollback exclusively in temporary directories."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location("delivery", Path(__file__).with_name("deploy-measured-client.py"))
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ix-measured-delivery-test-")
        self.base = Path(self.temp.name)
        self.root, self.game, self.out = self.base / "repo", self.base / "game", self.base / "out"
        self.out.mkdir()
        self.names = ["ixhl2rp/plugins/blackout/cl_lighting.lua", "ixhl2rp/plugins/status_display/cl_status.lua"]
        self.rows = []
        for name in self.names:
            source, local = self.root / name, self.game / name
            source.parent.mkdir(parents=True, exist_ok=True); source.write_text("new", encoding="utf-8")
            local.parent.mkdir(parents=True, exist_ok=True); local.write_text("old", encoding="utf-8")
            self.rows.append(dict(path=name, measuredClientPass=True, beforeSHA256=delivery.sha(local),
                                 afterSHA256=delivery.sha(source), localBeforeSHA256=delivery.sha(local), state="ready"))
        self.current = {row["path"]: row["afterSHA256"] for row in self.rows}
        self.patches = [patch.object(delivery, "ROOT", self.root), patch.object(delivery, "OUT", self.out),
                        patch.object(delivery, "GAME", self.game), patch.object(delivery, "runtime_hashes", return_value=self.current)]
        for p in self.patches: p.start()
        self.backup_patch = patch.object(delivery.tempfile, "gettempdir", return_value=str(self.base))
        self.backup_patch.start()

    def tearDown(self):
        self.backup_patch.stop()
        for p in reversed(self.patches): p.stop()
        self.temp.cleanup()

    def test_package_does_not_touch_local_and_verifies_members(self):
        prior = self.out / "prior.zip"
        with zipfile.ZipFile(prior, "w") as package: package.writestr("README-performance.txt", "SQLite rollback instructions")
        delivery.write_json(self.out / "core-safe-delivery.json", dict(archive=str(prior), archiveSHA256=delivery.sha(prior)))
        (self.out / "measured-client-verification.json").write_text("{}", encoding="utf-8")
        result = delivery.package_only(self.current, {"tests": {}}, self.rows)
        self.assertFalse(result["localUpdated"])
        self.assertEqual(result["cumulativeFiles"], 2)
        for row in self.rows: self.assertEqual(delivery.sha(self.game / row["path"]), row["localBeforeSHA256"])
        with zipfile.ZipFile(result["archive"]) as package:
            self.assertEqual(set(package.namelist()), set(self.names) | {"README-performance.txt"})
            self.assertIn(b"SQLite rollback instructions", package.read("README-performance.txt"))

    def test_apply_backs_up_all_originals_then_verifies_local(self):
        result = delivery.apply_local(self.current, self.rows, {}, {})
        self.assertTrue(result["localUpdated"])
        for row in self.rows:
            self.assertEqual(delivery.sha(self.game / row["path"]), row["afterSHA256"])
            self.assertEqual(delivery.sha(Path(result["backup"]) / row["path"]), row["localBeforeSHA256"])

    def test_divergence_is_backed_up_and_refused_without_overwrite(self):
        row = self.rows[0]; local = self.game / row["path"]
        local.write_text("user edit", encoding="utf-8"); row["localBeforeSHA256"] = delivery.sha(local); row["state"] = "divergent"
        with self.assertRaisesRegex(RuntimeError, "copying refused"):
            delivery.apply_local(self.current, self.rows, {}, {})
        backups = list(self.base.glob("ix-measured-client-local-backup-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(delivery.sha(backups[0] / row["path"]), row["localBeforeSHA256"])
        self.assertEqual(local.read_text(), "user edit")
        self.assertEqual((self.game / self.rows[1]["path"]).read_text(), "old")

    def test_copy_failure_rolls_back_originals(self):
        original = delivery.shutil.copy2
        def copy(source, target):
            if Path(source) == self.root / self.names[1]: raise OSError("injected write failure")
            return original(source, target)
        with patch.object(delivery.shutil, "copy2", side_effect=copy):
            with self.assertRaisesRegex(OSError, "injected"):
                delivery.apply_local(self.current, self.rows, {}, {})
        for row in self.rows: self.assertEqual(delivery.sha(self.game / row["path"]), row["localBeforeSHA256"])

    def test_unexpected_target_rejected(self):
        with self.assertRaises(ValueError): delivery.contained(self.game, "../outside.lua")
        with self.assertRaises(RuntimeError): delivery.contained(self.game, "addons/example.lua")


if __name__ == "__main__": unittest.main(verbosity=2)
