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

                GuideStep(number: 2, title: "Make 6 shortcuts") {
                    Text("In the **Shortcuts** app, open **All Shortcuts** and tap **+** for each one. They save on their own when you tap **‹**.")
                    NumberedLines(lines: [
                        "**Instagram Gate**: add **Check Access** (App: Instagram). Add **If** and make it read **If Check Access is No** (older iOS: **is False**). Add **Start Mindful Pause** (App: Instagram) and drag it between **If** and **Otherwise**.",
                        "**Instagram End**: add **End Session** (App: Instagram).",
                        "Press and hold each one, tap **Duplicate**, and make **TikTok Gate**, **TikTok End**, **YouTube Gate** and **YouTube End**. Change **every** App field in each copy.",
                    ])
                    Text("Rename a shortcut by tapping its name at the top. Don't rename them after step 3, because the automations find them by name.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                GuideStep(number: 3, title: "Make 6 automations") {
                    Text("In the **Automation** tab, tap **+** once for each line:")
                    Text("Instagram **opened** → Instagram Gate\nInstagram **closed** → Instagram End\nTikTok **opened** → TikTok Gate\nTikTok **closed** → TikTok End\nYouTube **opened** → YouTube Gate\nYouTube **closed** → YouTube End")
                        .font(.subheadline)
                    NumberedLines(lines: [
                        "If iOS asks **What do you want your shortcut to do?**, type for example: `When Instagram is opened, run my shortcut \"Instagram Gate\" immediately`",
                        "If you get a list of triggers instead, choose **App** → **Instagram** → tick only **Is Opened** → **Run Immediately** → **Next**, then pick **Instagram Gate**.",
                        "Either way, check that it runs immediately, without asking.",
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
                    Text("No pause? Check that the automation runs immediately, and that you've opened this app at least once since installing it. Pause names the wrong app? A copied shortcut still has the old app in one of its App fields.")
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
