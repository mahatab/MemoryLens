import SwiftUI

struct GlossaryView: View {
    @State private var searchText = ""
    @State private var selectedConcept: String?

    private var filteredGlossary: [(String, MemoryConceptInfo)] {
        if searchText.isEmpty {
            return MemoryEducation.glossary
        }
        let query = searchText.lowercased()
        return MemoryEducation.glossary.filter { name, info in
            name.lowercased().contains(query)
            || info.macDescription.lowercased().contains(query)
            || info.windowsEquivalent.lowercased().contains(query)
            || info.windowsDescription.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(selection: $selectedConcept) {
                Section {
                    ForEach(["Virtual vs Physical Memory", "Page Size", "Memory Pressure"], id: \.self) { name in
                        if let entry = filteredGlossary.first(where: { $0.0 == name }) {
                            NavigationLink(value: name) {
                                glossaryRow(name: entry.0, info: entry.1)
                            }
                        }
                    }
                } header: {
                    Text("Core Concepts")
                }

                Section {
                    ForEach(["Wired Memory", "Active Memory", "Inactive Memory", "Compressed Memory", "Purgeable Memory", "Free Memory"], id: \.self) { name in
                        if let entry = filteredGlossary.first(where: { $0.0 == name }) {
                            NavigationLink(value: name) {
                                glossaryRow(name: entry.0, info: entry.1)
                            }
                        }
                    }
                } header: {
                    Text("System Memory Categories")
                }

                Section {
                    ForEach(["__TEXT Segment", "__DATA Segment", "Heap", "Stack", "Dynamic Libraries", "Anonymous Memory", "Protection Flags (rwx)"], id: \.self) { name in
                        if let entry = filteredGlossary.first(where: { $0.0 == name }) {
                            NavigationLink(value: name) {
                                glossaryRow(name: entry.0, info: entry.1)
                            }
                        }
                    }
                } header: {
                    Text("Process Memory Regions")
                }
            }
            .searchable(text: $searchText, prompt: "Search concepts...")
            .navigationTitle("Memory Glossary")
            .navigationDestination(for: String.self) { name in
                if let info = MemoryEducation.glossary.first(where: { $0.0 == name })?.1 {
                    GlossaryDetailView(concept: info)
                }
            }
        }
    }

    @ViewBuilder
    private func glossaryRow(name: String, info: MemoryConceptInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.body.bold())
            HStack(spacing: 4) {
                Text("Windows:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(info.windowsEquivalent)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

struct GlossaryDetailView: View {
    let concept: MemoryConceptInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // macOS section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("macOS", systemImage: "apple.logo")
                            .font(.headline)
                        Text(concept.macDescription)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                // Windows section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Windows Equivalent", systemImage: "desktopcomputer")
                                .font(.headline)
                            Spacer()
                            Text(concept.windowsEquivalent)
                                .font(.callout.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.2))
                                .cornerRadius(6)
                        }
                        Text(concept.windowsDescription)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                // Deep dive section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Deep Dive", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)
                        Text(concept.learnMore)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }
            }
            .padding()
        }
        .navigationTitle(concept.title)
    }
}
