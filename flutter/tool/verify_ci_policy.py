#!/usr/bin/env python3
"""Guard release identity, signing secrets and publication policy in CI."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = ROOT.parent
WORKFLOW = REPOSITORY_ROOT / ".github" / "workflows" / "flutter-foundation.yml"
PUBSPEC = ROOT / "pubspec.yaml"
VERIFIER = ROOT / "tool" / "verify_release_apk.py"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"CI policy validation failed: {message}")


def main() -> None:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    pubspec = PUBSPEC.read_text(encoding="utf-8")
    verifier = VERIFIER.read_text(encoding="utf-8")

    version_match = re.search(r"(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$", pubspec)
    require(version_match is not None, "pubspec version must use name+code form.")
    version_name, version_code = version_match.groups()

    require("pull_request:" in workflow, "pull requests must execute the verification job.")
    require("flutter analyze" in workflow, "static analysis must run in CI.")
    require("flutter test --reporter expanded" in workflow, "unit tests must run in CI.")
    require("flutter build apk --release --target-platform android-arm64" in workflow,
            "ARM64 release build must run in CI.")
    require("tool/verify_release_apk.py" in workflow,
            "release APK verifier must run in CI.")
    require("verify --verbose --print-certs" in workflow and
            "APKSIGNER=" in workflow,
            "APK signature must be verified in CI.")

    signing_step = workflow.split("Load persistent Project Arena signing key", 1)
    require(len(signing_step) == 2, "persistent signing step is missing.")
    signing_header = signing_step[1].split("run: |", 1)[0]
    require(
        "if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'"
        in signing_header,
        "persistent signing secrets may only be loaded from trusted main builds.",
    )

    build_job, separator, release_job = workflow.partition("\n  publish-release:")
    require(separator, "release publication must be a separate job.")
    require(
        "if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'"
        in release_job,
        "release publication must be restricted to trusted main builds.",
    )
    require("needs: flutter-checks" in release_job,
            "release publication must depend on all build checks.")
    require("contents: write" in release_job,
            "release job must declare its own write permission.")
    require("overwrite_files: false" in release_job,
            "published release assets must never be silently replaced.")

    artifact_step = workflow.split("Upload trusted ARM64 update artifact", 1)
    require(len(artifact_step) == 2, "trusted APK artifact upload step is missing.")
    artifact_header = artifact_step[1].split("uses:", 1)[0]
    require(
        "if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'"
        in artifact_header,
        "update APK artifacts may only be uploaded from trusted main builds.",
    )

    legacy_workflow_path = REPOSITORY_ROOT / ".github" / "workflows" / "android.yml"
    legacy_workflow = legacy_workflow_path.read_text(encoding="utf-8")
    legacy_job = legacy_workflow.split("jobs:\\n  build:", 1)
    require(len(legacy_job) == 2, "legacy Android job definition is missing.")
    legacy_job_header = legacy_job[1].split("steps:", 1)[0]
    require(
        "if: false" in legacy_job_header,
        "the archived native Android workflow must remain disabled.",
    )
    require(
        "NEON_BREACH_KEYSTORE_BASE64" not in legacy_workflow,
        "the archived native workflow must not contain persistent signing secrets.",
    )
    require("Refuse to overwrite an existing version tag" in release_job,
            "release job must reject an existing version tag.")
    require("softprops/action-gh-release" not in build_job,
            "the build job must not publish directly.")

    require(
        f'manifest.get("versionName") == "{version_name}"' in verifier,
        "APK verifier versionName differs from pubspec.",
    )
    require(
        f"version_code == {version_code}" in verifier,
        "APK verifier versionCode differs from pubspec.",
    )
    require(
        f"Project-Arena-{version_name}-arm64.apk" in workflow,
        "versioned APK artifact name differs from pubspec.",
    )
    require(
        f"project-arena-{version_name}-arm64" in workflow,
        "artifact name differs from pubspec.",
    )
    require(
        f"project-arena-{version_name}" in workflow,
        "release tag differs from pubspec.",
    )
    require(
        f"Project-Arena-{version_name}-Changelog.txt" in workflow,
        "release changelog path differs from pubspec.",
    )

    print(
        "CI policy verified: "
        f"version={version_name}+{version_code}, "
        "PR checks enabled, signing restricted to main, "
        "release isolated, existing tags/assets protected."
    )


if __name__ == "__main__":
    main()
