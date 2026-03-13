# Auto Updater Design

Add automatic update checking via Sparkle 2, with updates hosted on GitHub Pages and binaries on GitHub Releases.

## Dependency & Configuration

**Sparkle 2 via SPM** — Added to `project.yml` as a Swift Package dependency, linked to the Countdown target.

**Info.plist additions:**
- `SUFeedURL` — `https://tavva.github.io/countdown/appcast.xml`
- `SUPublicEDKey` — EdDSA public key for verifying update signatures
- `SUEnableAutomaticChecks` — `true`

**EdDSA keypair** — Generated once via Sparkle's `generate_keys` tool. Private key stored locally (gitignored), used to sign DMGs during release. Public key ships in the app bundle via Info.plist.

No entitlements changes needed — `com.apple.security.network.client` already granted.

## App Integration

**UpdateManager** — Owns `SPUStandardUpdaterController`. Initialised at app startup with `startingUpdater: true` for automatic background checks.

- Single method: `checkForUpdates()` for manual trigger
- Sparkle handles all UI (download progress, release notes, install prompt) via standard macOS dialogs

**AppDelegate** — Creates and holds `UpdateManager` alongside `CalendarManager`.

**SettingsView** — Adds a "Check for Updates" button that calls `updateManager.checkForUpdates()`.

## UX

- Automatic background check on launch and periodically thereafter (Sparkle default: every 24 hours)
- When an update is available, Sparkle shows a standard macOS dialog with release notes, "Install" and "Skip" buttons
- Manual "Check for Updates" button in settings for on-demand checks

## Release Process

**Appcast hosting** — GitHub Pages from a `gh-pages` branch containing `appcast.xml`.

**`build-release.sh` additions** (after notarisation and stapling):
1. Sign DMG with EdDSA private key via Sparkle's `sign_update` tool
2. Update `appcast.xml` with new version entry (version, DMG URL, file size, EdDSA signature)
3. Push updated `appcast.xml` to `gh-pages` branch
4. Then proceed with existing tag + GitHub Release creation

**Appcast entries** point DMG download URLs at GitHub Releases (e.g. `https://github.com/tavva/countdown/releases/download/v1.0.0/Countdown.dmg`).

## Testing

No automated tests — UpdateManager is ~10 lines of configuration wrapping Sparkle. Manual verification during implementation:
- Sparkle dialog appears when appcast lists a newer version
- "Check for Updates" triggers correctly
- EdDSA signature verification works
