import SwiftUI
import Charts
import DoomCore

struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: Date(), by: 30)) { context in
                let summary = model.summary(at: context.date)
                ScrollView {
                    VStack(spacing: 20) {
                        if !model.data.onboardingDone {
                            setupCard
                        }
                        if let expiry = ProvisioningInfo.expirationDate,
                           expiry.timeIntervalSince(context.date) < 2 * 24 * 60 * 60 {
                            expiryCard(expiry)
                        }

                        BudgetRing(usedSeconds: summary.usedSeconds, budgetMinutes: summary.budgetMinutes)
                            .padding(.vertical, 8)

                        HStack(spacing: 12) {
                            StatTile(value: "\(summary.opens)", label: "pauses today")
                            StatTile(value: "\(summary.resisted)", label: "resisted")
                            StatTile(value: "\(model.streak(at: context.date))", label: "day streak")
                        }

                        perAppCard(summary)
                        planCard(at: context.date)
                        historyCard(at: context.date)
                    }
                    .padding()
                }
            }
            .navigationTitle("Today")
        }
    }

    // MARK: Cards

    private var setupCard: some View {
        NavigationLink {
            SetupGuideView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Finish setup").font(.headline)
                    Text("Connect Instagram, TikTok and YouTube with Shortcuts so the pause can appear.")
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .foregroundStyle(.white)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func expiryCard(_ expiry: Date) -> some View {
        Card(title: "Renew the app soon") {
            Text("With a free Apple ID, Stop Doomscroll stops opening on \(expiry.formatted(date: .abbreviated, time: .shortened)). Connect your iPhone to your Mac and press Run in Xcode to renew it.")
                .font(.subheadline)
        }
    }

    private func perAppCard(_ summary: DaySummary) -> some View {
        Card(title: "By app") {
            ForEach(TargetApp.allCases) { app in
                HStack {
                    Text(app.displayName)
                    Spacer()
                    Text(DisplayFormat.duration(summary.perApp[app] ?? 0))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func planCard(at date: Date) -> some View {
        Card(title: "Your plan") {
            Text(model.planDescription(at: date))
            if let pending = model.pendingChangeDescription(at: date) {
                Text(pending).foregroundStyle(.secondary)
            }
            Text("Screen Time backstop: set your App Limit to \(model.screenTimeLimitMinutes(at: date)) min.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func historyCard(at date: Date) -> some View {
        Card(title: "Last 7 days") {
            Chart(model.history(at: date)) { day in
                BarMark(
                    x: .value("Day", day.day, unit: .day),
                    y: .value("Minutes", day.usedSeconds / 60)
                )
                .foregroundStyle(day.isUnderBudget ? Color.accentColor : Color.red)

                LineMark(
                    x: .value("Day", day.day, unit: .day),
                    y: .value("Budget", day.budgetMinutes)
                )
                .interpolationMethod(.stepCenter)
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 160)
            Text("Bars are minutes used. The dashed line is your budget.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Building blocks

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct BudgetRing: View {
    let usedSeconds: TimeInterval
    let budgetMinutes: Int

    private var budgetSeconds: TimeInterval { TimeInterval(max(1, budgetMinutes) * 60) }
    private var progress: Double { min(1, usedSeconds / budgetSeconds) }
    private var isOver: Bool { usedSeconds >= budgetSeconds }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(isOver ? Color.red : Color.accentColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(usedSeconds / 60))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("of \(budgetMinutes) min")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 220, height: 220)
    }
}
