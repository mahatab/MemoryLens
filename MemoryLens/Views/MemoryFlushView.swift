import SwiftUI

struct MemoryFlushView: View {
    @StateObject private var service = MemoryStatsService()
    @State private var beforeStats: SystemMemoryStats?
    @State private var afterStats: SystemMemoryStats?
    @State private var isPurging = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                warningBanner
                purgeSection
                if let before = beforeStats, let after = afterStats {
                    comparisonSection(before: before, after: after)
                }
                if let error = errorMessage {
                    errorBanner(error)
                }
            }
            .padding()
        }
        .navigationTitle("Memory Flush")
    }

    @ViewBuilder
    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Requires administrator privileges.")
                    .font(.callout.bold())
                Text("Results may vary with SIP enabled. Run with sudo for best results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.orange.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var purgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Purge Inactive Memory")
                .font(.headline)

            Text("This runs the macOS `purge` command, which forces the system to flush inactive and purgeable memory pages. Useful for memory testing and benchmarking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    Task { await runPurge() }
                } label: {
                    HStack {
                        if isPurging {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isPurging ? "Purging..." : "Purge Inactive Memory")
                    }
                }
                .disabled(isPurging)
                .controlSize(.large)

                Spacer()

                if beforeStats != nil || afterStats != nil {
                    Button("Reset") {
                        beforeStats = nil
                        afterStats = nil
                        errorMessage = nil
                    }
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func comparisonSection(before: SystemMemoryStats, after: SystemMemoryStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Before / After Comparison")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Category")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Before")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("After")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Change")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Divider()
                comparisonRow("Free", before: before.free, after: after.free, positiveIsGood: true)
                comparisonRow("Active", before: before.active, after: after.active, positiveIsGood: false)
                comparisonRow("Inactive", before: before.inactive, after: after.inactive, positiveIsGood: false)
                comparisonRow("Wired", before: before.wired, after: after.wired, positiveIsGood: false)
                comparisonRow("Compressed", before: before.compressed, after: after.compressed, positiveIsGood: false)
                comparisonRow("Purgeable", before: before.purgeable, after: after.purgeable, positiveIsGood: false)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func comparisonRow(_ label: String, before: UInt64, after: UInt64, positiveIsGood: Bool) -> some View {
        let delta = Int64(after) - Int64(before)
        let deltaColor: Color = {
            if delta == 0 { return .secondary }
            let isPositive = delta > 0
            return (isPositive == positiveIsGood) ? .green : .red
        }()

        GridRow {
            Text(label)
            Text(ByteFormatter.format(before)).monospacedDigit()
            Text(ByteFormatter.format(after)).monospacedDigit()
            Text(deltaString(delta))
                .monospacedDigit()
                .foregroundStyle(deltaColor)
        }
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
            Spacer()
        }
        .padding()
        .background(.red.opacity(0.1))
        .cornerRadius(8)
    }

    private func deltaString(_ delta: Int64) -> String {
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : ""
        return sign + ByteFormatter.format(delta)
    }

    private func runPurge() async {
        isPurging = true
        errorMessage = nil

        service.refresh()
        beforeStats = service.stats

        do {
            try await Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
                let errorPipe = Pipe()
                process.standardError = errorPipe
                process.standardOutput = FileHandle.nullDevice

                try process.run()
                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    throw PurgeError.failed(errorString.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }.value

            service.refresh()
            afterStats = service.stats

        } catch let error as PurgeError {
            switch error {
            case .failed(let message):
                errorMessage = message.isEmpty
                    ? "Purge failed. Run with administrator privileges (sudo)."
                    : message
            }
        } catch {
            errorMessage = "Purge failed: \(error.localizedDescription)"
        }

        isPurging = false
    }
}

private enum PurgeError: Error {
    case failed(String)
}
