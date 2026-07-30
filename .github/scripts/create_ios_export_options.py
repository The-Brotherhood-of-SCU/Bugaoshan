"""Create deterministic Xcode export options for the signed iOS archive."""

import argparse
import json
import plistlib
from pathlib import Path


APP_BUNDLE_ID = "io.github.thebrotherhoodofscu.bugaoshan"
WIDGET_BUNDLE_ID = "io.github.thebrotherhoodofscu.bugaoshan.CourseWidget"


def _validate_profile_name(raw_profiles, bundle_id, requested_name):
    try:
        profiles = json.loads(raw_profiles)
    except json.JSONDecodeError as error:
        raise ValueError(f"Invalid provisioning profile JSON for {bundle_id}") from error

    if not isinstance(profiles, list) or not profiles:
        raise ValueError(f"No provisioning profile found for {bundle_id}")

    names = {
        profile.get("name", "")
        for profile in profiles
        if isinstance(profile, dict) and profile.get("name")
    }
    if not names:
        raise ValueError(f"Provisioning profiles for {bundle_id} have no name")
    if requested_name not in names:
        available = ", ".join(sorted(names))
        raise ValueError(
            f"Provisioning profile {requested_name!r} was not downloaded for "
            f"{bundle_id}; available: {available}"
        )
    return requested_name


def create_export_options(
    team_id,
    app_profiles,
    widget_profiles,
    app_profile_name,
    widget_profile_name,
    output,
):
    if not team_id:
        raise ValueError("Apple Team ID is required")

    payload = {
        "manageAppVersionAndBuildNumber": False,
        "method": "app-store-connect",
        "provisioningProfiles": {
            APP_BUNDLE_ID: _validate_profile_name(
                app_profiles, APP_BUNDLE_ID, app_profile_name
            ),
            WIDGET_BUNDLE_ID: _validate_profile_name(
                widget_profiles, WIDGET_BUNDLE_ID, widget_profile_name
            ),
        },
        "signingCertificate": "Apple Distribution",
        "signingStyle": "manual",
        "stripSwiftSymbols": True,
        "teamID": team_id,
        "uploadSymbols": True,
    }
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as destination:
        plistlib.dump(payload, destination, sort_keys=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--app-profiles-json", required=True)
    parser.add_argument("--widget-profiles-json", required=True)
    parser.add_argument("--app-profile-name", required=True)
    parser.add_argument("--widget-profile-name", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    create_export_options(
        args.team_id,
        args.app_profiles_json,
        args.widget_profiles_json,
        args.app_profile_name,
        args.widget_profile_name,
        args.output,
    )


if __name__ == "__main__":
    main()
