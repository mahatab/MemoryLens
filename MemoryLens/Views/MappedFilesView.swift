import SwiftUI

struct MappedFilesView: View {
    let pid: pid_t
    let processName: String

    @State private var regions: [VMRegionInfo] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if isLoading {
                Spacer()
                ProgressView("Loading memory regions...")
                Spacer()
            } else if regions.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No regions available")
                        .font(.headline)
                    Text("This process may require elevated privileges to inspect.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                regionsTable
            }
        }
        .navigationTitle("Mapped Files")
        .task {
            await loadRegions()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await loadRegions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh regions")
            }
        }
    }

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            Text("\(processName)")
                .font(.headline)
            Text("(PID: \(pid))")
                .foregroundStyle(.secondary)
            Spacer()
            if !regions.isEmpty {
                Text("\(regions.count) regions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.3))
    }

    @ViewBuilder
    private var regionsTable: some View {
        Table(regions) {
            TableColumn("Start Address") { region in
                Text(String(format: "0x%016llx", region.startAddress))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 140, ideal: 170)

            TableColumn("End Address") { region in
                Text(String(format: "0x%016llx", region.endAddress))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 140, ideal: 170)

            TableColumn("Size") { region in
                Text(ByteFormatter.format(region.size))
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 80)

            TableColumn("Prot") { region in
                HStack(spacing: 4) {
                    Text(region.protection)
                        .font(.system(.body, design: .monospaced))
                    ConceptInfoButton(concept: MemoryEducation.protectionFlags)
                }
            }
            .width(min: 60, ideal: 80)

            TableColumn("Type") { region in
                HStack(spacing: 4) {
                    Text(region.regionType)
                    if let concept = MemoryEducation.info(for: region.regionType) {
                        ConceptInfoButton(concept: concept)
                    }
                }
            }
            .width(min: 80, ideal: 120)

            TableColumn("Mapped File") { region in
                Text(region.mappedFile)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 150, ideal: 300)
        }
    }

    private func loadRegions() async {
        isLoading = true
        let result = await Task.detached {
            VMRegionService.fetchRegions(for: pid)
        }.value
        regions = result
        isLoading = false
    }
}
