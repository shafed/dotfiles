#!/usr/bin/env python3
import importlib.util
import pathlib
import sys
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "generate_logbook.py"
spec = importlib.util.spec_from_file_location("generate_logbook", SCRIPT)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
assert spec.loader is not None
spec.loader.exec_module(module)


class FilenameFormatTest(unittest.TestCase):
    def test_canonical_training_filename_is_accepted(self):
        match = module.FILENAME_RE.fullmatch("2026-08-25-Training")
        self.assertIsNotNone(match)
        self.assertEqual(match.groups()[:3], ("2026", "08", "25"))

    def test_legacy_day_filename_remains_accepted(self):
        match = module.FILENAME_RE.fullmatch("2026-01-03-Day-2")
        self.assertIsNotNone(match)
        self.assertEqual(match.groups()[:3], ("2026", "01", "03"))

    def test_arbitrary_suffix_is_rejected(self):
        self.assertIsNone(module.FILENAME_RE.fullmatch("2026-08-25-Rings"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
