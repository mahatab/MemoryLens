import SwiftUI
import Charts

struct MemorySegment: Identifiable {
    var id: String { category }
    let category: String
    let bytes: UInt64
    let color: Color

    var megabytes: Double {
        Double(bytes) / (1_024 * 1_024)
    }
}

struct SystemMemoryView: View {
    @StateObject private var service = MemoryStatsService()
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                chartSection
                statsGrid
                vmActivitySection
            }
            .padding()
        }
        .navigationTitle("System Memory")
        .onReceive(timer) { _ in
            service.refresh()
        }
    }

    private var segments: [MemorySegment] {
        [
            MemorySegment(category: "Wired", bytes: service.stats.wired, color: .red),
            MemorySegment(category: "Active", bytes: service.stats.active, color: .blue),
            MemorySegment(category: "Inactive", bytes: service.stats.inactive, color: .yellow),
            MemorySegment(category: "Compressed", bytes: service.stats.compressed, color: .purple),
            MemorySegment(category: "Purgeable", bytes: service.stats.purgeable, color: .green),
            MemorySegment(category: "Free", bytes: service.stats.free, color: .gray),
        ]
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Physical RAM")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(ByteFormatter.format(service.stats.totalRAM))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Used")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(ByteFormatter.format(service.stats.used))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memory Composition")
                .font(.headline)

            Chart(segments) { segment in
                BarMark(
                    x: .value("MB", segment.megabytes)
                )
                .foregroundStyle(by: .value("Type", segment.category))
            }
            .chartForegroundStyleScale(domain: segments.map(\.category), range: segments.map(\.color))
            .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
            .frame(height: 50)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Category").font(.subheadline).foregroundStyle(.secondary)
                    Text("").font(.subheadline) // info button column
                    Text("Size").font(.subheadline).foregroundStyle(.secondary)
                    Text("Pages").font(.subheadline).foregroundStyle(.secondary)
                    Text("% of Total").font(.subheadline).foregroundStyle(.secondary)
                }
                Divider()
                ForEach(segments) { segment in
                    GridRow {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 10, height: 10)
                            Text(segment.category)
                        }
                        if let concept = MemoryEducation.info(for: segment.category) {
                            ConceptInfoButton(concept: concept)
                        } else {
                            Text("")
                        }
                        Text(ByteFormatter.format(segment.bytes))
                            .monospacedDigit()
                        Text(pageCount(for: segment.bytes))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", service.stats.percentage(of: segment.bytes)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var vmActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Virtual Memory Activity")
                    .font(.headline)
                ConceptInfoButton(concept: MemoryEducation.virtualVsPhysical)
            }

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    vmStatItem("Swap Used", value: ByteFormatter.format(service.stats.swapUsed))
                    vmStatItem("Page Faults", value: formatCount(service.stats.pageFaults))
                    vmStatItem("COW Faults", value: formatCount(service.stats.cowFaults))
                }
                GridRow {
                    vmStatItem("Page Ins", value: formatCount(service.stats.pageins))
                    vmStatItem("Page Outs", value: formatCount(service.stats.pageouts))
                    vmStatItem("Reactivations", value: formatCount(service.stats.reactivations))
                }
                GridRow {
                    vmStatItem("Swap Ins", value: formatCount(service.stats.swapins))
                    vmStatItem("Swap Outs", value: formatCount(service.stats.swapouts))
                    vmStatItem("Purges", value: formatCount(service.stats.purges))
                }
                GridRow {
                    vmStatItem("Compressions", value: formatCount(service.stats.compressions))
                    vmStatItem("Decompressions", value: formatCount(service.stats.decompressions))
                    Text("")
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func vmStatItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.bold().monospacedDigit())
        }
        .frame(minWidth: 120, alignment: .leading)
    }

    private func formatCount(_ value: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func pageCount(for bytes: UInt64) -> String {
        let pages = bytes / UInt64(vm_page_size)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: pages)) ?? "\(pages)") + " pages"
    }
}
