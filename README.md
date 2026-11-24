# Stop Doomscroll

An iPhone app that adds friction before **Instagram, TikTok and YouTube**, and gives them a daily time budget that shrinks every week.

- **A mindful pause before every open.** You breathe for 15 seconds, say why you're opening the app, and choose 5, 10 or 15 minutes. The biggest button on the screen is always "I don't need it".
- **A daily budget shared by all three apps** that steps down weekly: 90 → 75 → 60 → 45 → 30 → 15 min. Once it's used up, the apps are blocked until midnight. The only way past that is one emergency unlock per day, which comes after a 2-minute wait.
- **Rules against impulse changes.** Lowering the budget takes effect immediately. Raising it only takes effect tomorrow.
- **Stats**: minutes per app, pauses, how many times you resisted, a streak of days under budget, and a 7-day chart.
- **Works with a free Apple ID.** You don't need a paid developer account.

## How it works

Apple's Screen Time API, which commercial blockers use, isn't available to free developer accounts. This app uses three pieces that are:

1. **Shortcuts automations.** "When Instagram is opened" runs the app's **Check Access** action. If you're not inside a session you chose, it runs **Start Mindful Pause**, and Stop Doomscroll appears on top of Instagram. "When Instagram is closed" runs **End Session**, which records how long you actually spent in the app.
2. **This app.** It runs the pause and block screens, keeps track of the budget, and shows your stats. All data stays on your phone.
3. **iOS's own Screen Time App Limit**, set to your budget + 10 min, with a passcode chosen by someone else. It's a backstop for weak moments: it still works if you switch off an automation or the app expires.

```
Tap Instagram ──► automation: Check Access ──True──► Instagram opens, timer starts
                                  │
                                False
                                  ▼
                     Start Mindful Pause ──► Stop Doomscroll
                                  │
               budget left?  ─────┴───── budget used up?
                     ▼                          ▼
     breathe → why? → 5/10/15 min       Block screen until midnight
                     ▼
     Instagram opens (no second pause during the session)
```

Limits worth knowing:

- iOS doesn't let a free app close another app. When a session ends you get a notification, and your next open needs a new pause.
- With a free Apple ID, apps you install yourself stop opening after **7 days**. Re-run the project from Xcode to renew it; your data is kept. The app reminds you the day before.

## Getting started

You need a Mac with Xcode, your iPhone and a cable. Full steps are in **[docs/SETUP.md](docs/SETUP.md)**.

```bash
./scripts/bootstrap.sh
```

The script installs XcodeGen, creates your signing config, generates the Xcode project and opens it. Pick your Personal Team in Xcode and press Run. The app's built-in setup guide then walks you through the Shortcuts automations.

## Project layout

```
project.yml                  XcodeGen spec (the .xcodeproj is generated, not committed)
Config/                      Signing settings (App.xcconfig + your git-ignored Local.xcconfig)
Packages/DoomCore/           Pure-Swift logic with unit tests: budget plan, ledger, gatekeeper, stats, storage
StopDoomscroll/App/          App entry point, AppModel (shared state), formatting
StopDoomscroll/Intents/      Shortcuts actions: Check Access, Start Mindful Pause, End Session
StopDoomscroll/Services/     Local notifications, provisioning-profile expiry
StopDoomscroll/Views/        Pause, Block, Today, Settings, Setup guide
docs/SETUP.md                Install and setup guide
```

## Tests

The logic that decides whether an app opens is in `Packages/DoomCore` and has unit tests:

```bash
cd Packages/DoomCore && swift test
```
