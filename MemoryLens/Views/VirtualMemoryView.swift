import SwiftUI
import Charts

struct VMActivityEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let metric: String
    let value: Double
}

struct VirtualMemoryView: View {
    @StateObject private var service = MemoryStatsService()
    @State private var history: [VMActivitySnapshot] = []
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let maxPoints = 150

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                swapSection
                pagingActivitySection
                compressionSection
                activityChart
            }
            .padding()
        }
        .navigationTitle("Virtual Memory")
        .onReceive(timer) { _ in
            service.refresh()
            recordSnapshot()
        }
        .onAppear {
            service.refresh()
            recordSnapshot()
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Virtual Memory Overview")
                    .font(.title2.bold())
                Text("Paging, swapping, and compression activity since boot")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ConceptInfoButton(concept: MemoryEducation.virtualVsPhysical)
        }
    }

    @ViewBuilder
    private var swapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Swap Usage")
                    .font(.headline)
                Spacer()
                Text(ByteFormatter.format(service.stats.swapUsed))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(service.stats.swapUsed > 0 ? .orange : .green)
            }

            if service.stats.swapUsed > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("System is using swap. Physical RAM is under pressure — the OS is paging data to disk.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("No swap in use. All data fits in physical RAM + compression.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Windows comparison note
            HStack(spacing: 6) {
                Image(systemName: "desktopcomputer")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("Windows equivalent: Page File (pagefile.sys). Check in Task Manager → Performance → Memory → \"Committed\".")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.blue.opacity(0.05))
            .cornerRadius(6)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var pagingActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paging Activity (since boot)")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 12) {
                GridRow {
                    statCard("Page Faults", value: fmt(service.stats.pageFaults),
                             detail: "Total VM faults — includes soft faults (resolved from cache) and hard faults (required disk I/O).",
                             windows: "Hard Page Faults in Task Manager. Windows distinguishes hard vs soft; macOS reports total.")
                    statCard("Page Ins", value: fmt(service.stats.pageins),
                             detail: "Pages read from disk into RAM. High values mean frequent disk-backed reads.",
                             windows: "Pages Input/sec in Performance Monitor (perfmon).")
                }
                GridRow {
                    statCard("Page Outs", value: fmt(service.stats.pageouts),
                             detail: "Pages written from RAM to swap file. Non-zero means memory pressure caused eviction.",
                             windows: "Pages Output/sec in perfmon. High values indicate thrashing.")
                    statCard("COW Faults", value: fmt(service.stats.cowFaults),
                             detail: "Copy-on-write faults — triggered when a process writes to a shared page, creating a private copy.",
                             windows: "No direct Windows equivalent in standard tools. COW works similarly at kernel level.")
                }
                GridRow {
                    statCard("Reactivations", value: fmt(service.stats.reactivations),
                             detail: "Pages moved from Inactive back to Active — the cache worked! The page was needed again before eviction.",
                             windows: "Similar to Standby → Active transition in Windows. High values mean the Standby cache is effective.")
                    statCard("Purges", value: fmt(service.stats.purges),
                             detail: "Purgeable pages reclaimed by the kernel. The data was discarded without writing to disk.",
                             windows: "Similar to low-priority Standby pages being repurposed in Windows.")
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var compressionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Compression")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 12) {
                GridRow {
                    statCard("Compressions", value: fmt(service.stats.compressions),
                             detail: "Pages compressed in RAM to save space. macOS compresses before swapping to disk.",
                             windows: "Compressed pages in Task Manager → Memory. Windows 10+ has this feature.")
                    statCard("Decompressions", value: fmt(service.stats.decompressions),
                             detail: "Pages decompressed when accessed. Decompression is much faster than reading from SSD.",
                             windows: "No direct counter in Task Manager. Visible in perfmon as Memory\\Compression operations.")
                }
                GridRow {
                    statCard("Swap Ins", value: fmt(service.stats.swapins),
                             detail: "Compressed pages read back from swap file. These were too compressed-heavy and got written to disk.",
                             windows: "Page file reads in Resource Monitor → Memory tab.")
                    statCard("Swap Outs", value: fmt(service.stats.swapouts),
                             detail: "Compressed pages written to swap file. System ran low on physical RAM even after compression.",
                             windows: "Page file writes in Resource Monitor → Memory tab.")
                }
            }

            // Compression ratio insight
            let ratio = service.stats.compressions > 0
                ? Double(service.stats.decompressions) / Double(service.stats.compressions) * 100
                : 0
            HStack(spacing: 8) {
                Image(systemName: "archivebox")
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Decompression/compression ratio: \(String(format: "%.1f%%", ratio))")
                        .font(.caption)
                    Text(ratio > 80 ? "High reuse — compressed pages are being accessed frequently."
                         : "Low reuse — compressed pages mostly stay compressed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func statCard(_ label: String, value: String, detail: String, windows: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.bold())
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                Image(systemName: "desktopcomputer")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text(windows)
                    .font(.caption2)
                    .foregroundStyle(.orange.opacity(0.8))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var activityChart: some View {
        if history.count >= 2 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Swap Usage Over Time")
                    .font(.headline)

                Chart(history) { snapshot in
                    LineMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("MB", Double(snapshot.swapUsed) / (1_024 * 1_024))
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.monotone)
                }
                .chartYAxisLabel("MB")
                .frame(height: 150)
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .cornerRadius(12)
        }
    }

    private func fmt(_ value: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func recordSnapshot() {
        history.append(VMActivitySnapshot(
            timestamp: Date(),
            swapUsed: service.stats.swapUsed
        ))
        if history.count > maxPoints {
            history.removeFirst(history.count - maxPoints)
        }
    }
}

private struct VMActivitySnapshot: Identifiable {
    let id = UUID()
    let timestamp: Date
    let swapUsed: UInt64
}
