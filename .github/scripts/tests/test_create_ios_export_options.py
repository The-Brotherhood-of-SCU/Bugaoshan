import json
import plistlib
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

import create_ios_export_options


class CreateIosExportOptionsTest(unittest.TestCase):
    def test_creates_manual_export_options_for_app_and_widget(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "ExportOptions.plist"
            create_ios_export_options.create_export_options(
                "2F6UXH5569",
                json.dumps([{"name": "Bugaoshan App Store", "type": "IOS_APP_STORE"}]),
                json.dumps([{"name": "Bugaoshan Widget", "type": "IOS_APP_STORE"}]),
                "Bugaoshan App Store",
                "Bugaoshan Widget",
                output,
            )

            with output.open("rb") as source:
                payload = plistlib.load(source)

            self.assertEqual(payload["method"], "app-store-connect")
            self.assertEqual(payload["signingStyle"], "manual")
            self.assertEqual(payload["teamID"], "2F6UXH5569")
            self.assertEqual(
                payload["provisioningProfiles"],
                {
                    create_ios_export_options.APP_BUNDLE_ID: "Bugaoshan App Store",
                    create_ios_export_options.WIDGET_BUNDLE_ID: "Bugaoshan Widget",
                },
            )

    def test_rejects_missing_profiles(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, "No provisioning profile"):
                create_ios_export_options.create_export_options(
                    "2F6UXH5569",
                    "[]",
                    json.dumps([{"name": "Bugaoshan Widget"}]),
                    "Bugaoshan App Store",
                    "Bugaoshan Widget",
                    Path(temp) / "ExportOptions.plist",
                )


if __name__ == "__main__":
    unittest.main()
