import SwiftUI

struct ProcessMemoryView: View {
    @StateObject private var service = ProcessListService()
    @State private var sortOrder = [KeyPathComparator(\ProcessInfo.residentSize, order: .reverse)]
    @State private var selectedProcessID: pid_t?
    var onInspectProcess: (ProcessInfo) -> Void
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            if !service.isRoot {
                rootWarningBanner
            }

            Table(sortedProcesses, selection: $selectedProcessID, sortOrder: $sortOrder) {
                TableColumn("PID", value: \.pid) { process in
                    Text("\(process.pid)")
                        .monospacedDigit()
                }
                .width(min: 50, ideal: 60, max: 80)

                TableColumn("Name", value: \.name) { process in
                    Text(process.name)
                }
                .width(min: 120, ideal: 200)

                TableColumn("RSS", value: \.residentSize) { process in
                    Text(ByteFormatter.format(process.residentSize))
                        .monospacedDigit()
                }
                .width(min: 80, ideal: 100, max: 120)

                TableColumn("Virtual Size", value: \.virtualSize) { process in
                    Text(ByteFormatter.format(process.virtualSize))
                        .monospacedDigit()
                }
                .width(min: 80, ideal: 100, max: 120)
            }

            HStack {
                Text("\(service.processes.count) processes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !service.isRoot {
                    Text("Processes with 0 B RSS may require elevated privileges")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .navigationTitle("Process Memory")
        .onReceive(timer) { _ in
            service.refresh()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    if let pid = selectedProcessID,
                       let process = service.processes.first(where: { $0.pid == pid }) {
                        onInspectProcess(process)
                    }
                } label: {
                    Label("View Regions", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(selectedProcessID == nil)
                .help("View memory regions for selected process")
            }
        }
    }

    private var sortedProcesses: [ProcessInfo] {
        service.processes.sorted(using: sortOrder)
    }

    @ViewBuilder
    private var rootWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Some processes may be hidden — run with sudo for full visibility.")
                .font(.callout)
            Spacer()
        }
        .padding(10)
        .background(.yellow.opacity(0.1))
    }
}
