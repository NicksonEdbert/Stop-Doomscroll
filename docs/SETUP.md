# Setting up Stop Doomscroll

Total time: about 20 minutes, once. After that, about 1 minute every 7 days to renew.

You need:

- A Mac with **Xcode** installed (free from the Mac App Store)
- Your **iPhone** on iOS 17 or later, and a cable to connect it to the Mac
- Your **Apple ID** (a free one is fine)

---

## Part 1 – Install the app from your Mac

### 1. Get the code and generate the Xcode project

```bash
git clone https://github.com/NicksonEdbert/Stop-Doomscroll.git
```

```bash
cd Stop-Doomscroll
```

```bash
./scripts/bootstrap.sh
```

The script:

- installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) with Homebrew if you don't have it (it needs [Homebrew](https://brew.sh) for that)
- asks for a short name, which it uses to make a bundle ID only you have, such as `com.nickson.stopdoomscroll`, saved in `Config/Local.xcconfig`
- generates `StopDoomscroll.xcodeproj` and opens it in Xcode

### 2. Sign in and choose your team

1. In Xcode, go to **Xcode → Settings → Accounts → +** and sign in with your Apple ID (skip this if you're already signed in).
2. In the left sidebar, click the blue **StopDoomscroll** project, then the **StopDoomscroll** target, then **Signing & Capabilities**.
3. Under **Team**, choose **Your Name (Personal Team)**.

> If you run `xcodegen generate` again later, you'll need to pick the team again. To skip that, put your team ID in `Config/Local.xcconfig` as `DEVELOPMENT_TEAM = XXXXXXXXXX`. You can see the ID in Build Settings → Development Team after picking it once.

### 3. Prepare the iPhone

1. Connect the iPhone to the Mac with the cable. Unlock it and tap **Trust** if it asks.
2. On the iPhone, open **Settings → Privacy & Security → Developer Mode** and turn it on. The phone restarts. After the restart, confirm by tapping **Turn On**.

   (The Developer Mode option only appears after the phone has been connected to Xcode once.)

### 4. Run it

1. At the top of Xcode, choose your iPhone as the run destination.
2. Press **⌘R** (or the ▶︎ button).
3. The first time, the iPhone will refuse to open the app because the developer isn't trusted. On the iPhone, go to **Settings → General → VPN & Device Management**, tap your Apple ID, then tap **Trust**.
4. Press **⌘R** again. Stop Doomscroll opens on your phone.

**Open the app at least once.** Its Shortcuts actions only show up in the Shortcuts app after that.

---

## Part 2 – Set up the iPhone

The app's **Today** tab has a **Finish setup** card with these same steps. They're repeated here so you can read them on the Mac while you set up the phone.

### 5. Allow notifications

In the setup guide, tap **Allow notifications**. Notifications tell you when a session ends, when the budget runs out, when the weekly step-down happens, and when the app needs renewing.

### 6. Make 6 shortcuts

Build the actions as ordinary shortcuts first. They save themselves, which is more reliable than building actions inside an automation. In the **Shortcuts** app, open **All Shortcuts** and tap **+**.

1. **Instagram Gate**
   1. Add **Check Access** and set **App** to **Instagram**.
   2. Add **If**. It should read **If Check Access is No** (older iOS versions say *is False*). If an extra empty **Condition** row appears, remove it with **⊖**.
   3. Add **Start Mindful Pause**, set **App** to **Instagram**, and drag it so it sits **between "If" and "Otherwise"**.
   4. Tap the name at the top → **Rename** → `Instagram Gate`. Tap **‹** to save.
2. **Instagram End**: a new shortcut with one action, **End Session**, with **App** set to **Instagram**.
3. Press and hold each of them, tap **Duplicate**, and make **TikTok Gate**, **TikTok End**, **YouTube Gate** and **YouTube End**. In each copy, change **every** App field. If one is left behind, opening YouTube shows "Opening TikTok".

A finished gate looks like this:

```
Check access to Instagram
If Check Access is No
    Start a mindful pause for Instagram
Otherwise
End If
```

Don't rename these six after step 7. The automations find them by name.

### 7. Make 6 automations

In the **Automation** tab, tap **+** once for each row:

| When | Is | Run shortcut |
|---|---|---|
| Instagram | Opened | Instagram Gate |
| Instagram | Closed | Instagram End |
| TikTok | Opened | TikTok Gate |
| TikTok | Closed | TikTok End |
| YouTube | Opened | YouTube Gate |
| YouTube | Closed | YouTube End |

What **+** does depends on your iOS version:

- **Newer iOS** asks *"What do you want your shortcut to do?"*. Type the row as a sentence, for example:

  ```
  When Instagram is opened, run my shortcut "Instagram Gate" immediately
  ```

  Check that the result shows the right app, **Opened** or **Closed**, and the right shortcut. Then tap **‹** to save.
- **Older iOS** shows a list of triggers. Choose **App** → **Choose** → **Instagram**, tick only **Is Opened**, select **Run Immediately**, turn **Notify When Run** off, and tap **Next**. Then pick **Instagram Gate** from the list instead of New Blank Automation.

Either way, each automation must run immediately, without asking. On newer iOS the automations also appear in All Shortcuts (for example "Run Shortcut When Instagram Opens"). That's normal, and you can leave them there.

### 8. Set the Screen Time backstop (strongly recommended)

Automations can be turned off in a weak moment. iOS's own App Limit can't be, if someone else holds the passcode.

1. Open **Settings → Screen Time** and turn it on if it's off.
2. Tap **Lock Screen Time Settings**. Ask a friend or family member to type a passcode you don't know.
3. Tap **App Limits → Add Limit**. Expand the categories and tick **Instagram**, **TikTok** and **YouTube**. Tap **Next**.
4. Set the time to your budget **+ 10 minutes** (100 min in week 1). Keep **Block at End of Limit** on. Tap **Add**.
5. Each week the app notifies you that the budget dropped. Ask the passcode holder to lower the limit to match. The Today tab always shows the right number.

### 9. Test it

| Do this | You should see |
|---|---|
| Open Instagram | The pause screen appears within about a second |
| Finish the pause and pick 5 min | Instagram opens, without another pause |
| Switch to another app and back within the 5 min | No pause |
| Close Instagram, then open Stop Doomscroll | Today shows the minutes you used |
| After 5 min | A "session over" notification. The next open shows the pause again |
| Settings → Testing → **Set budget to 1 min**, then use Instagram for a minute and close it | The next open shows the **block screen** |

The **Testing** section only appears in builds run from Xcode. **Erase all data** resets the app after testing.

---

## Every 7 days: renew

Apps installed with a free Apple ID stop opening after 7 days. The day before that, you'll get a notification. Then:

1. Connect the iPhone to the Mac (after the first time, being on the same Wi-Fi often works too).
2. Open the project in Xcode and press **⌘R**.

Your data and automations are kept. You can see the exact expiry date in **Settings → App expires**.

If you forget, the app won't open, and the automations stop until you renew. The Screen Time App Limit from step 8 still protects you in the meantime.

---

## Troubleshooting

**Instagram opens with no pause.**
Check that the automation says **Run Immediately** and that its **App** fields are set. Open Stop Doomscroll once, so iOS knows its actions exist. Also check the app hasn't expired (see "Every 7 days" above).

**The pause shows the wrong app (for example "Opening TikTok" when you opened YouTube).**
That gate shortcut was copied from another one, and one of its App fields still has the old app. Open it in All Shortcuts and set **both** actions to the right app. Check the matching **End** shortcut too.

**Tapping ‹ doesn't save my automation.**
Build the actions as a normal shortcut in All Shortcuts first (step 6), then make an automation that just runs it (step 7).

**The pause keeps coming back right after I pick a time.**
The **If** step is probably set to *is Yes* / *is True*, or **Start Mindful Pause** sits outside the If block. Compare with the example in step 6.

**Shortcuts says it can't find "Check Access".**
Open Stop Doomscroll once, then search again. If that doesn't help, delete and re-add the action.

**TikTok doesn't open after the pause.**
The app tries TikTok's known link schemes. If none of them work, it tells you to open TikTok yourself. Your session has already started, so you won't get another pause.

**"Unable to install … no more than 3 apps" or "bundle ID unavailable".**
Free Apple IDs can have up to 3 self-installed apps at once, and bundle IDs must be unique. Delete an old self-installed app, or change `PRODUCT_BUNDLE_IDENTIFIER` in `Config/Local.xcconfig` and run `xcodegen generate` again.
