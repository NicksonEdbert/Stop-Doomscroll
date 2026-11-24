import SwiftUI
import DoomCore

/// Shown when today's budget is used up. There's no open button, only a once-a-day
/// emergency unlock behind a two-minute wait.
struct BlockedView: View {
    let app: TargetApp

    @EnvironmentObject private var model: AppModel

    static let emergencyWaitSeconds = 120

    /// nil until you ask for the emergency unlock.
    @State private var emergencySecondsLeft: Int?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            Text("That's today's budget")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("You've used your \(model.budgetMinutes()) min. \(app.displayName) unlocks again at midnight, in \(model.timeUntilMidnightText).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            if emergencyAvailable {
                emergencySection
            }

            Button {
                model.dismissRoute()
            } label: {
                Text("OK, close")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private var emergencyAvailable: Bool {
        if case .blocked(let available) = model.decision(for: app) {
            return available
        }
        return false
    }

    @ViewBuilder
    private var emergencySection: some View {
        if let left = emergencySecondsLeft {
            if left > 0 {
                Text("Emergency unlock in \(left) s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Button("Open \(app.displayName) for \(Ledger.emergencyMinutes) min") {
                    model.useEmergency(for: app)
                }
                .buttonStyle(.bordered)
            }
        } else {
            VStack(spacing: 4) {
                Button("Emergency: I really need it") {
                    startEmergencyCountdown()
                }
                .font(.footnote)
                Text("Once a day · \(Self.emergencyWaitSeconds / 60) min wait · counts as a slip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startEmergencyCountdown() {
        emergencySecondsLeft = Self.emergencyWaitSeconds
        Task { @MainActor in
            while let left = emergencySecondsLeft, left > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                emergencySecondsLeft = left - 1
            }
        }
    }
}
