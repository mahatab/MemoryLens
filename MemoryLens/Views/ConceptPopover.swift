import SwiftUI

struct ConceptInfoButton: View {
    let concept: MemoryConceptInfo

    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.blue)
                .font(.caption)
        }
        .buttonStyle(.plain)
        .help("Learn about \(concept.title)")
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            ConceptPopoverContent(concept: concept)
        }
    }
}

struct ConceptPopoverContent: View {
    let concept: MemoryConceptInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(concept.title)
                    .font(.title3.bold())

                conceptSection(
                    icon: "apple.logo",
                    label: "macOS",
                    text: concept.macDescription
                )

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "windows")
                            .foregroundStyle(.blue)
                        Text("Windows Equivalent:")
                            .font(.subheadline.bold())
                        Text(concept.windowsEquivalent)
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    Text(concept.windowsDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text("Deep Dive")
                            .font(.subheadline.bold())
                    }
                    Text(concept.learnMore)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .frame(width: 380, height: 400)
    }

    @ViewBuilder
    private func conceptSection(icon: String, label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.subheadline.bold())
            }
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
