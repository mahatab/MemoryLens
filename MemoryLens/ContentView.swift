import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case systemMemory = "System Memory"
    case virtualMemory = "Virtual Memory"
    case timeline = "Timeline"
    case processMemory = "Process Memory"
    case mappedFiles = "Mapped Files"
    case snapshotCompare = "Snapshot & Compare"
    case memoryFlush = "Memory Flush"
    case glossary = "Memory Glossary"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .systemMemory: return "memorychip"
        case .virtualMemory: return "arrow.left.arrow.right"
        case .timeline: return "chart.xyaxis.line"
        case .processMemory: return "list.bullet"
        case .mappedFiles: return "doc.text"
        case .snapshotCompare: return "camera.on.rectangle"
        case .memoryFlush: return "arrow.triangle.2.circlepath"
        case .glossary: return "book.closed"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .systemMemory
    @State private var inspectedProcess: ProcessInfo?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Memory") {
                    ForEach([SidebarItem.systemMemory, .virtualMemory, .timeline], id: \.self) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                }
                Section("Processes") {
                    ForEach([SidebarItem.processMemory, .mappedFiles], id: \.self) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                }
                Section("Tools") {
                    ForEach([SidebarItem.snapshotCompare, .memoryFlush], id: \.self) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                }
                Section("Learn") {
                    NavigationLink(value: SidebarItem.glossary) {
                        Label(SidebarItem.glossary.rawValue, systemImage: SidebarItem.glossary.icon)
                    }
                }
            }
            .navigationTitle("MemoryLens")
            .listStyle(.sidebar)
        } detail: {
            detailView
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .systemMemory:
            SystemMemoryView()
        case .virtualMemory:
            VirtualMemoryView()
        case .timeline:
            MemoryTimelineView()
        case .processMemory:
            ProcessMemoryView(onInspectProcess: { process in
                inspectedProcess = process
                selection = .mappedFiles
            })
        case .mappedFiles:
            if let process = inspectedProcess {
                MappedFilesView(pid: process.pid, processName: process.name)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Select a process from Process Memory view")
                        .font(.headline)
                    Text("Use the \"View Regions\" toolbar button to inspect a process's memory map.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Go to Process Memory") {
                        selection = .processMemory
                    }
                }
            }
        case .snapshotCompare:
            SnapshotCompareView()
        case .memoryFlush:
            MemoryFlushView()
        case .glossary:
            GlossaryView()
        case nil:
            Text("Select a view from the sidebar")
                .foregroundStyle(.secondary)
        }
    }
}
