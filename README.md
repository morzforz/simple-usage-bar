# Simple Usage Bar

Tiny macOS menu-bar app that shows **Grok Code** (Grok Build CLI) subscription **usage %** and **reset time**.

## Requirements

- macOS 14+ (Sonoma)
- [Xcode](https://developer.apple.com/xcode/) 16+ (full app, not only Command Line Tools)
- [Grok Build CLI](https://docs.x.ai/build/overview) installed and signed in

## Sign in (CLI auth only)

This app does **not** open a browser login. It reuses credentials from the Grok CLI:

```bash
grok login
```

Credentials are read from `~/.grok/auth.json` (or `$GROK_HOME/auth.json` if set).  
If the access token expires, run `grok` or `grok login` again, then use **Refresh** in the popover (or wait for the auth-file watcher).

## Build and run

From the repo root:

```bash
./Scripts/build_and_run.sh
```

Options:

```bash
./Scripts/build_and_run.sh --clean    # clean build
./Scripts/build_and_run.sh --no-run   # build only
./Scripts/build_and_run.sh --release
```

Or open `SimpleUsageBar.xcodeproj` in Xcode and run the **SimpleUsageBar** scheme.

If `xcode-select` points at Command Line Tools only, the script sets:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

## Tests

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -scheme SimpleUsageBar -configuration Debug \
  -project SimpleUsageBar.xcodeproj test
```

## Notifications

When usage first reaches **80%** or **100%**, the app can show a macOS notification (you will be asked for permission once). It will not re-notify for the same threshold until usage drops back below that level.

## What you see

- Menu bar: Grok logo + compact percent (e.g. `43%`) and a mini usage bar as a **system template** (black/white adaptive)  
  - Popover still uses green / yellow / red bands (&lt;70 / 70–90 / ≥90)
- Popover: percent bar, reset time, account email, status messages, **Refresh**, **Launch at Login**, **Quit**

## Unofficial billing API (best-effort)

Usage is fetched with your CLI bearer token from an **unofficial** gRPC-web billing endpoint (`GetGrokCreditsConfig` on grok.com). Field layouts can change without notice. Treat numbers as best-effort; this project is not affiliated with xAI.

## Privacy

- No passwords stored by this app
- No browser cookies or Keychain browser import
- Tokens are not logged
- Network only to the Grok billing host for usage fetch

## License

Project-local; see repository owner for distribution terms.
