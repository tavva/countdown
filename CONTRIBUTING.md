# Contributing to Countdown

Thanks for your interest in contributing! Here's how to get started.

## Getting Set Up

1. Fork and clone the repo
2. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
3. Set up Google OAuth credentials — see [README](README.md#google-oauth-credentials)
4. Generate the Xcode project: `xcodegen generate`
5. Build and run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build`

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

The Xcode project is generated from `project.yml`. If you need to add files or change targets, edit `project.yml` and run `xcodegen generate` — don't edit the `.xcodeproj` directly.

Tests use the [Swift Testing](https://developer.apple.com/documentation/testing) framework (`@Test`, `#expect`), not XCTest.

## Licence

By contributing, you agree that your contributions will be licensed under the [GPL v3](LICENCE).
