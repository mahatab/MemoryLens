import SwiftUI
import Charts

struct MemorySnapshot: Identifiable {
    let id = UUID()
    let timestamp: Date
    let label: String
    let stats: SystemMemoryStats
}

struct SnapshotCompareView: View {
    @StateObject private var service = MemoryStatsService()
    @State private var snapshots: [MemorySnapshot] = []
    @State private var snapshotLabel = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                instructionBanner
                captureSection
                if snapshots.count >= 2 {
                    comparisonChart
                }
                snapshotsList
            }
            .padding()
        }
        .navigationTitle("Snapshot & Compare")
    }

    @ViewBuilder
    private var instructionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("Capture snapshots to see how memory changes")
                    .font(.callout.bold())
                Text("Take a snapshot, perform an action (open an app, run a command), then take another snapshot to compare.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.blue.opacity(0.08))
        .cornerRadius(10)
    }

    @ViewBuilder
    private var captureSection: some View {
        HStack {
            TextField("Label (e.g. \"Before opening Safari\")", text: $snapshotLabel)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)

            Button {
                captureSnapshot()
            } label: {
                Label("Capture Snapshot", systemImage: "camera")
            }
            .controlSize(.large)

            Spacer()

            if !snapshots.isEmpty {
                Button(role: .destructive) {
                    snapshots.removeAll()
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var comparisonChart: some View {
        let latest = snapshots.suffix(2)
        let first = latest.first!
        let second = latest.last!

        VStack(alignment: .leading, spacing: 12) {
            Text("Comparison: \(first.label) vs \(second.label)")
                .font(.headline)

            let data = comparisonData(before: first.stats, after: second.stats)

            Chart(data, id: \.category) { item in
                BarMark(
                    x: .value("MB", item.megabytes),
                    y: .value("Category", item.category)
                )
                .foregroundStyle(by: .value("Snapshot", item.snapshot))
                .position(by: .value("Snapshot", item.snapshot))
            }
            .chartForegroundStyleScale(domain: [first.label, second.label], range: [.blue, .orange])
            .frame(height: 250)

            // Delta table
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Category").font(.subheadline.bold())
                    Text(first.label).font(.subheadline.bold()).foregroundStyle(.blue)
                    Text(second.label).font(.subheadline.bold()).foregroundStyle(.orange)
                    Text("Change").font(.subheadline.bold())
                }
                Divider()
                deltaRow("Free", before: first.stats.free, after: second.stats.free, positiveIsGood: true)
                deltaRow("Active", before: first.stats.active, after: second.stats.active, positiveIsGood: false)
                deltaRow("Inactive", before: first.stats.inactive, after: second.stats.inactive, positiveIsGood: false)
                deltaRow("Wired", before: first.stats.wired, after: second.stats.wired, positiveIsGood: false)
                deltaRow("Compressed", before: first.stats.compressed, after: second.stats.compressed, positiveIsGood: false)
                deltaRow("Purgeable", before: first.stats.purgeable, after: second.stats.purgeable, positiveIsGood: false)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func deltaRow(_ label: String, before: UInt64, after: UInt64, positiveIsGood: Bool) -> some View {
        let delta = Int64(after) - Int64(before)
        let color: Color = {
            if delta == 0 { return .secondary }
            return (delta > 0) == positiveIsGood ? .green : .red
        }()

        GridRow {
            Text(label)
            Text(ByteFormatter.format(before)).monospacedDigit()
            Text(ByteFormatter.format(after)).monospacedDigit()
            Text(deltaString(delta))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private var snapshotsList: some View {
        if !snapshots.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Snapshots (\(snapshots.count))")
                    .font(.headline)

                ForEach(snapshots) { snapshot in
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snapshot.label)
                                .font(.callout.bold())
                            Text(snapshot.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Free: \(ByteFormatter.format(snapshot.stats.free))")
                            .font(.caption)
                            .monospacedDigit()
                        Text("Active: \(ByteFormatter.format(snapshot.stats.active))")
                            .font(.caption)
                            .monospacedDigit()
                        Text("Compressed: \(ByteFormatter.format(snapshot.stats.compressed))")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
    }

    private func captureSnapshot() {
        service.refresh()
        let label = snapshotLabel.isEmpty ? "Snapshot \(snapshots.count + 1)" : snapshotLabel
        snapshots.append(MemorySnapshot(
            timestamp: Date(),
            label: label,
            stats: service.stats
        ))
        snapshotLabel = ""
    }

    private func deltaString(_ delta: Int64) -> String {
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : ""
        return sign + ByteFormatter.format(delta)
    }

    private struct ComparisonItem {
        let category: String
        let snapshot: String
        let megabytes: Double
    }

    private func comparisonData(before: SystemMemoryStats, after: SystemMemoryStats) -> [ComparisonItem] {
        let firstLabel = snapshots[snapshots.count - 2].label
        let secondLabel = snapshots[snapshots.count - 1].label

        func mb(_ bytes: UInt64) -> Double { Double(bytes) / (1_024 * 1_024) }

        return [
            ComparisonItem(category: "Free", snapshot: firstLabel, megabytes: mb(before.free)),
            ComparisonItem(category: "Free", snapshot: secondLabel, megabytes: mb(after.free)),
            ComparisonItem(category: "Active", snapshot: firstLabel, megabytes: mb(before.active)),
            ComparisonItem(category: "Active", snapshot: secondLabel, megabytes: mb(after.active)),
            ComparisonItem(category: "Inactive", snapshot: firstLabel, megabytes: mb(before.inactive)),
            ComparisonItem(category: "Inactive", snapshot: secondLabel, megabytes: mb(after.inactive)),
            ComparisonItem(category: "Wired", snapshot: firstLabel, megabytes: mb(before.wired)),
            ComparisonItem(category: "Wired", snapshot: secondLabel, megabytes: mb(after.wired)),
            ComparisonItem(category: "Compressed", snapshot: firstLabel, megabytes: mb(before.compressed)),
            ComparisonItem(category: "Compressed", snapshot: secondLabel, megabytes: mb(after.compressed)),
            ComparisonItem(category: "Purgeable", snapshot: firstLabel, megabytes: mb(before.purgeable)),
            ComparisonItem(category: "Purgeable", snapshot: secondLabel, megabytes: mb(after.purgeable)),
        ]
    }
}
