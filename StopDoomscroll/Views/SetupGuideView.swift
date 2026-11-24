import SwiftUI
import DoomCore

/// Walks through the one-time setup: notifications, the Shortcuts automations that trigger the
/// pause, and the Screen Time backstop.
struct SetupGuideView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var notificationsOn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("About 10 minutes, once. Afterwards every open of Instagram, TikTok or YouTube goes through a pause first.")
                    .foregroundStyle(.secondary)

                GuideStep(number: 1, title: "Turn on notifications") {
                    Text("They tell you when a session is over, when the budget runs out, when the plan steps down, and when the app needs renewing.")
                    if notificationsOn {
                        Label("Notifications are on", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Allow notifications") {
                            Task {
                                await Notifications.requestPermission()
                                notificationsOn = await Notifications.isAuthorized()
                                model.refreshReminders()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                GuideStep(number: 2, title: "Add the \"opened\" automation (once per app)") {
                    Text("Do this for **Instagram**, then repeat it for **TikTok** and **YouTube**.")
                    NumberedLines(lines: [
                        "Open the **Shortcuts** app and go to the **Automation** tab.",
                        "Tap **+** (or **New Automation**) and choose **App**.",
                        "Tap **Choose**, pick **Instagram**, tap **Done**. Tick **Is Opened** and untick **Is Closed**.",
                        "Choose **Run Immediately** and turn **Notify When Run** off. Tap **Next**.",
                        "Tap **New Blank Automation**.",
                        "Add the **Check Access** action (search \"Check Access\") and set **App** to **Instagram**.",
                        "Add the **If** action. Its input should already be **Check Access**. Set the condition to **is False**.",
                        "Add **Start Mindful Pause**, set **App** to **Instagram**, and drag it so it sits between **If** and **Otherwise**.",
                        "Tap **Done**.",
                    ])
                }

                GuideStep(number: 3, title: "Add the \"closed\" automation (once per app)") {
                    Text("This is how the app measures your minutes. Again for all three apps.")
                    NumberedLines(lines: [
                        "In **Automation**, tap **+** → **App** → choose **Instagram**.",
                        "Tick **Is Closed** and untick **Is Opened**. **Run Immediately**, **Notify When Run** off. **Next**.",
                        "**New Blank Automation** → add **End Session**, set **App** to **Instagram**. **Done**.",
                    ])
                }

                GuideStep(number: 4, title: "Set the Screen Time backstop") {
                    Text("Shortcuts automations can be switched off in a weak moment. iOS's own App Limit can't, if someone else holds the passcode.")
                    NumberedLines(lines: [
                        "Open **Settings** → **Screen Time** and turn it on.",
                        "Tap **Lock Screen Time Settings** and have a friend or family member type a passcode you don't know.",
                        "Tap **App Limits** → **Add Limit**. Expand the categories and tick **Instagram**, **TikTok** and **YouTube**.",
                        "Set the limit to **\(model.screenTimeLimitMinutes()) min** (your budget plus 10) and keep **Block at End of Limit** on.",
                        "When the weekly notification says the budget dropped, ask them to lower the limit to match.",
                    ])
                }

                GuideStep(number: 5, title: "Test it") {
                    NumberedLines(lines: [
                        "Open Instagram. The pause should appear within a second.",
                        "Finish the pause and pick 5 min. Instagram should open, without another pause.",
                        "Switch away and back. No pause while the 5 min last.",
                        "Close Instagram, come back here: **Today** should show the minutes.",
                    ])
                    Text("If Instagram opens with no pause, check the automation is set to **Run Immediately** and that you've opened this app at least once since installing it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                GuideStep(number: 6, title: "Renew every 7 days") {
                    Text("Apps installed with a free Apple ID stop opening after 7 days. Plug your iPhone into your Mac and press **Run** in Xcode before then. Your data is kept. You'll get a reminder the day before.")
                    if let expiry = ProvisioningInfo.expirationDate {
                        Text("This install expires \(expiry.formatted(date: .abbreviated, time: .shortened)).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    model.completeOnboarding()
                    dismiss()
                } label: {
                    Text(model.data.onboardingDone ? "Done" : "I've finished setup")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationTitle("Setup")
        .task { notificationsOn = await Notifications.isAuthorized() }
    }
}

private struct GuideStep<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.accentColor, in: Circle())
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                content
            }
        }
    }
}

private struct NumberedLines: View {
    let lines: [LocalizedStringKey]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1).")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(line)
                }
            }
        }
        .font(.subheadline)
    }
}
