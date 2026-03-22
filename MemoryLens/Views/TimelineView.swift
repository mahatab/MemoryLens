import SwiftUI
import Charts

struct MemoryTimelineEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let megabytes: Double
}

struct MemoryTimelineView: View {
    @StateObject private var service = MemoryStatsService()
    @State private var history: [[MemoryTimelineEntry]] = []
    @State private var isRecording = true
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private let maxDataPoints = 150 // 5 minutes at 2s intervals

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBar
            timelineChart
            legendGrid
        }
        .padding()
        .navigationTitle("Memory Timeline")
        .onReceive(timer) { _ in
            guard isRecording else { return }
            service.refresh()
            recordDataPoint()
        }
        .onAppear {
            service.refresh()
            recordDataPoint()
        }
    }

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live Memory History")
                    .font(.headline)
                Text("Showing memory composition over time (2s intervals)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                Text("\(flatEntries.count / 6) data points")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    isRecording.toggle()
                } label: {
                    Label(isRecording ? "Pause" : "Resume",
                          systemImage: isRecording ? "pause.fill" : "play.fill")
                }

                Button {
                    history.removeAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var timelineChart: some View {
        if flatEntries.isEmpty {
            VStack(spacing: 8) {
                ProgressView()
                Text("Collecting data...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
        } else {
            Chart(flatEntries) { entry in
                AreaMark(
                    x: .value("Time", entry.timestamp),
                    y: .value("MB", entry.megabytes)
                )
                .foregroundStyle(by: .value("Type", entry.category))
            }
            .chartForegroundStyleScale(domain: categoryOrder, range: categoryColors)
            .chartYAxisLabel("MB")
            .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
            .frame(minHeight: 300)
            .padding()
            .background(.quaternary.opacity(0.3))
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private var legendGrid: some View {
        HStack(spacing: 20) {
            currentStat("Free", value: service.stats.free, color: .gray)
            currentStat("Active", value: service.stats.active, color: .blue)
            currentStat("Inactive", value: service.stats.inactive, color: .yellow)
            currentStat("Wired", value: service.stats.wired, color: .red)
            currentStat("Compressed", value: service.stats.compressed, color: .purple)
            currentStat("Purgeable", value: service.stats.purgeable, color: .green)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func currentStat(_ label: String, value: UInt64, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(ByteFormatter.format(value))
                .font(.callout.bold().monospacedDigit())
        }
    }

    private var flatEntries: [MemoryTimelineEntry] {
        history.flatMap { $0 }
    }

    private let categoryOrder = ["Wired", "Active", "Inactive", "Compressed", "Purgeable", "Free"]
    private let categoryColors: [Color] = [.red, .blue, .yellow, .purple, .green, .gray]

    private func recordDataPoint() {
        let now = Date()
        let s = service.stats

        func mb(_ bytes: UInt64) -> Double { Double(bytes) / (1_024 * 1_024) }

        let entries = [
            MemoryTimelineEntry(timestamp: now, category: "Wired", megabytes: mb(s.wired)),
            MemoryTimelineEntry(timestamp: now, category: "Active", megabytes: mb(s.active)),
            MemoryTimelineEntry(timestamp: now, category: "Inactive", megabytes: mb(s.inactive)),
            MemoryTimelineEntry(timestamp: now, category: "Compressed", megabytes: mb(s.compressed)),
            MemoryTimelineEntry(timestamp: now, category: "Purgeable", megabytes: mb(s.purgeable)),
            MemoryTimelineEntry(timestamp: now, category: "Free", megabytes: mb(s.free)),
        ]

        history.append(entries)

        if history.count > maxDataPoints {
            history.removeFirst(history.count - maxDataPoints)
        }
    }
}
