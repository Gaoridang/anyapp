# AGENTS.md

## Cursor Cloud specific instructions

`anyapp` is an **iOS + SwiftUI (SwiftData/AVFoundation/Speech)** application. The app itself
can only be built, run, and tested on **macOS with Xcode** (CI builds it on `macos-26` via
`fastlane beta` — see `.github/workflows/testflight.yml` and `docs/release.md`).

Cursor Cloud agents run on **Linux**, where Xcode, the iOS Simulator, and the Apple
frameworks are unavailable. Therefore:

- **Do not attempt to build/run/test the iOS app on Linux** (no `xcodebuild`, no Swift
  toolchain for Apple frameworks, no Simulator). Swift source edits must be reviewed
  statically or validated on a macOS machine / CI.
- The **Linux-runnable surface** is the CI + release configuration tooling only:
  - `bash scripts/verify_ci_config.sh` — validates the TestFlight/CI configuration (this is
    the `ci-verify` GitHub workflow, `runs-on: ubuntu-latest`).
  - `bash scripts/test_app_icons.sh` — regenerates + validates `AppIcon` PNGs via
    `python3 scripts/generate_app_icons.py` (deterministic; produces no git diff).
  - `bash scripts/test_write_asc_api_key.sh` — validates the App Store Connect key writer
    using `openssl` (uses throwaway keys; no secrets needed).
  - `bundle exec fastlane lanes` — parses `fastlane/Fastfile` and lists lanes. The `beta`
    lane cannot execute on Linux (it needs Xcode + App Store Connect secrets), but listing
    lanes confirms the Ruby release tooling loads.

### Notes / gotchas

- `python3`, `openssl`, `file`, and `base64` are preinstalled system tools; the bash/python
  scripts need no extra install.
- Ruby tooling uses a vendored bundle: `bundle config set --local path vendor/bundle`
  then `bundle install` (the update script does this). `vendor/bundle/` and `.bundle/` are
  gitignored. The system Bundler (2.4.x) differs from the lockfile's `BUNDLED WITH 4.0.2`;
  this only prints a note and does not block `bundle install`.
- Fastlane prints a warning that Ruby 3.2 support is going away; harmless for lane listing.
- `Secrets.xcconfig` (see `Secrets.xcconfig.example`) is only needed for actual Xcode
  builds on macOS; it is not required for the Linux checks above.
