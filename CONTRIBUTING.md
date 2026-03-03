# Contributing to Countdown

Thanks for your interest in contributing! Here's how to get started.

## Getting Set Up

### Google OAuth Credentials

You'll need your own Google OAuth credentials to run from source:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project (or select an existing one)
3. Enable the **Google Calendar API**
4. Go to **Credentials** → **Create Credentials** → **OAuth client ID**
5. Choose **Desktop app** as the application type
6. Copy the **Client ID** and **Client Secret**

### Build & Run

1. Fork and clone the repo
2. Add your OAuth credentials:
   ```bash
   cp Countdown/Config.plist.template Countdown/Config.plist
   # Edit Config.plist — fill in GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET
   ```
3. Build and run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build`

Or open `Countdown.xcodeproj` in Xcode and hit Run.

## Making Changes

1. Create a branch from `main`
2. Make your changes
3. Run the tests: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test`
4. Open a pull request against `main`

## Guidelines

- Keep changes small and focused — one concern per PR
- Add tests for new functionality
- Match the style of the surrounding code
- No external dependencies — the project uses only native frameworks

## Project Structure

The Xcode project is generated from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). If you need to add files or change targets, install XcodeGen (`brew install xcodegen`), edit `project.yml`, and run `xcodegen generate` — don't edit the `.xcodeproj` directly.

Tests use the [Swift Testing](https://developer.apple.com/documentation/testing) framework (`@Test`, `#expect`), not XCTest.

## Licence

By contributing, you agree that your contributions will be licensed under the [GPL v3](LICENCE).
