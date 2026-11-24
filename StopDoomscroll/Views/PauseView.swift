import SwiftUI
import DoomCore

/// The mindful pause shown before a target app opens.
///
/// Breathe for 15 seconds, say why you're opening it, pick how long. The big button at the
/// bottom always closes without opening.
struct PauseView: View {
    let app: TargetApp

    @EnvironmentObject private var model: AppModel

    static let breathSeconds = 15

    private enum Step {
        case breathing, intention, bored, duration
    }

    @State private var step: Step = .breathing
    @State private var secondsLeft = PauseView.breathSeconds
    @State private var inhale = false
    @State private var intention: Intention?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Opening \(app.displayName)")
                    .font(.largeTitle.bold())
                Text(model.pauseSubtitle(for: app))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            Spacer()

            Group {
                switch step {
                case .breathing: breathing
                case .intention: intentionPicker
                case .bored: boredSuggestions
                case .duration: durationPicker
                }
            }
            .transition(.opacity)

            Spacer()

            Button {
                model.resist(app, intention: intention)
            } label: {
                Text("I don't need \(app.displayName)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .task { await runCountdown() }
    }

    // MARK: Steps

    private var breathing: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                Circle()
                    .fill(Color.accentColor.opacity(0.35))
                    .scaleEffect(inhale ? 1.0 : 0.45)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: inhale)
                Text("\(secondsLeft)")
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 240, height: 240)

            Text("Breathe in as the circle grows, out as it shrinks.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .onAppear { inhale = true }
    }

    private var intentionPicker: some View {
        VStack(spacing: 12) {
            Text("What are you opening it for?")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 4)
            ForEach(Intention.allCases, id: \.self) { item in
                Button {
                    choose(item)
                } label: {
                    Text(item.label).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var boredSuggestions: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("Boredom passes.")
                .font(.title2.weight(.semibold))
            Text("The urge usually fades within a few minutes. Try one of these instead:")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                Label("Walk around for 5 minutes", systemImage: "figure.walk")
                Label("Drink a glass of water", systemImage: "drop")
                Label("Text or call a friend", systemImage: "message")
                Label("Read two pages of a book", systemImage: "book")
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            Button("Open it anyway") {
                withAnimation { step = .duration }
            }
            .font(.footnote)
            .padding(.top, 8)
        }
    }

    private var durationPicker: some View {
        let options = Gatekeeper.sessionOptions(remainingSeconds: model.remainingSeconds())
        return VStack(spacing: 14) {
            if options.isEmpty {
                Text("Today's budget just ran out.")
                    .font(.title3.weight(.semibold))
            } else {
                Text("For how long?")
                    .font(.title3.weight(.semibold))
                HStack(spacing: 12) {
                    ForEach(options, id: \.self) { minutes in
                        Button("\(minutes) min") {
                            model.grantSession(for: app, minutes: minutes, intention: intention)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                Text("You'll get a notification when the time is up.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Logic

    private func choose(_ item: Intention) {
        intention = item
        withAnimation { step = item == .bored ? .bored : .duration }
    }

    @MainActor
    private func runCountdown() async {
        while secondsLeft > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            secondsLeft -= 1
        }
        withAnimation { step = .intention }
    }
}
