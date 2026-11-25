import SwiftUI
import DoomCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    @State private var useStepDown = true
    @State private var fixedMinutes = 30
    @State private var resultMessage: String?
    @State private var notificationsOn = false
    #if DEBUG
    @State private var confirmingTestBudget = false
    @State private var confirmingErase = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget") {
                    LabeledContent("Today", value: "\(model.budgetMinutes()) min")
                    Text(model.planDescription())
                    if let pending = model.pendingChangeDescription() {
                        Text(pending).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Picker("Plan", selection: $useStepDown) {
                        Text("Step down weekly").tag(true)
                        Text("Fixed").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if !useStepDown {
                        Stepper("\(fixedMinutes) min a day", value: $fixedMinutes, in: 5...240, step: 5)
                    }

                    Button("Apply") { apply() }
                } header: {
                    Text("Change budget")
                } footer: {
                    Text("Lowering applies right away. Raising only applies from tomorrow, so a craving can't buy more time today. The step-down plan goes 90 → 75 → 60 → 45 → 30 → 15 min, one step a week.")
                }

                Section("Help") {
                    NavigationLink("Setup guide") { SetupGuideView() }
                    if !notificationsOn {
                        Button("Turn on notifications") {
                            Task {
                                await Notifications.requestPermission()
                                notificationsOn = await Notifications.isAuthorized()
                                model.refreshReminders()
                            }
                        }
                    }
                    if let expiry = ProvisioningInfo.expirationDate {
                        LabeledContent("App expires", value: expiry.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                #if DEBUG
                Section {
                    Button("Set budget to 1 min (applies now)") {
                        confirmingTestBudget = true
                    }
                    .alert("Set the budget to 1 minute?", isPresented: $confirmingTestBudget) {
                        Button("Set to 1 min", role: .destructive) {
                            model.requestBudget(.fixed(minutes: 1))
                            loadCurrentMode()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This is only for testing the block screen. It applies right away and stays at 1 min a day until you change it. Raising it again only takes effect tomorrow, so Instagram, TikTok and YouTube stay blocked for the rest of today.")
                    }

                    Button("Erase all data", role: .destructive) {
                        confirmingErase = true
                    }
                    .alert("Erase all data?", isPresented: $confirmingErase) {
                        Button("Erase", role: .destructive) {
                            model.eraseAllData()
                            loadCurrentMode()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This deletes your minutes, pauses and streak, and restarts the plan at 90 min a day from today. Your shortcuts and automations aren't affected.")
                    }
                } header: {
                    Text("Testing")
                } footer: {
                    Text("Only in builds run from Xcode in Debug.")
                }
                #endif
            }
            .navigationTitle("Settings")
            .onAppear { loadCurrentMode() }
            .task { notificationsOn = await Notifications.isAuthorized() }
            .alert(
                "Budget",
                isPresented: Binding(
                    get: { resultMessage != nil },
                    set: { if !$0 { resultMessage = nil } }
                )
            ) {
                Button("OK") {}
            } message: {
                Text(resultMessage ?? "")
            }
        }
    }

    private func loadCurrentMode() {
        // Show the pending choice if there is one, so the form matches what's coming.
        let mode = model.data.plan.pendingChange(after: Date(), calendar: model.calendar)?.mode ?? model.currentMode()
        switch mode {
        case .stepDown:
            useStepDown = true
        case .fixed(let minutes):
            useStepDown = false
            fixedMinutes = min(240, max(5, minutes - minutes % 5))
        }
    }

    private func apply() {
        let before = model.budgetMinutes()
        let mode: BudgetMode = useStepDown ? .stepDown : .fixed(minutes: fixedMinutes)
        let change = model.requestBudget(mode)
        let newMinutes = model.data.plan.minutes(for: mode, on: change.effectiveDay, calendar: model.calendar)

        if model.calendar.isDateInToday(change.effectiveDay) {
            resultMessage = "Done. Today's budget is now \(newMinutes) min."
        } else {
            resultMessage = "That's a raise, so it starts tomorrow at \(newMinutes) min. Today stays at \(before) min."
        }
    }
}
