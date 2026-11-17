# Localview Installer – working rules

- **Never add an update to an existing release.** Each app change raises `version:` in `pubspec.yaml` and is released as its own `v<version>`; the workflow fails if that release already exists.
- Docs/CI-only commits (`*.md`, `.github/**`) don't trigger a release.
