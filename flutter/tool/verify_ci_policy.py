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

    profile_build = workflow.split("Build ARM64 profile APK for PR runtime validation", 1)
    require(len(profile_build) == 2, "PR profile QA build step is missing.")
    profile_build_header = profile_build[1].split("run:", 1)[0]
    require(
        "if: github.event_name == 'pull_request'" in profile_build_header,
        "profile QA APK may only be built for pull requests.",
    )
    require(
        "flutter build apk --profile --target-platform android-arm64" in profile_build[1],
        "PR profile QA build must target ARM64 profile mode.",
    )

    qa_identity = workflow.split("Isolate PR profile application identity", 1)
    require(len(qa_identity) == 2, "isolated PR profile identity step is missing.")
    qa_identity_header = qa_identity[1].split("run:", 1)[0]
    require(
        "if: github.event_name == 'pull_request'" in qa_identity_header
        and "tool/prepare_profile_qa_identity.py" in qa_identity[1],
        "isolated QA application identity must be prepared only for pull requests.",
    )
    require(
        "verify_release_apk.py build/app/outputs/flutter-apk/app-profile.apk --qa-profile" in profile_build[1],
        "profile APK verifier must enforce the isolated QA application identity.",
    )

    android_generator = (ROOT / "tool" / "prepare_android.py").read_text(encoding="utf-8")
    require(
        "def add_arm64_abi_filter(" in android_generator
        and "content = add_arm64_abi_filter(content, gradle)" in android_generator
        and "abiFilters.clear()" in android_generator
        and 'abiFilters.addAll(listOf("arm64-v8a"))' in android_generator
        and 'abiFilters "arm64-v8a"' in android_generator,
        "Android host generator must clear Flutter ABI defaults and enforce ARM64 only.",
    )

    profile_artifact = workflow.split("Upload profile QA artifact", 1)
    require(len(profile_artifact) == 2, "PR profile QA artifact upload step is missing.")
    profile_artifact_header = profile_artifact[1].split("uses:", 1)[0]
    require(
        "if: github.event_name == 'pull_request'" in profile_artifact_header,
        "profile QA artifacts may only be uploaded from pull requests.",
    )
    require(
        f"project-arena-{version_name}-arm64-profile-qa" in profile_artifact[1],
        "PR profile QA artifact name is missing or inconsistent.",
    )
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
    legacy_job = legacy_workflow.split("jobs:\n  build:", 1)
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
