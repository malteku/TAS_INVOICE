import SwiftUI

// Einfache Markdown-Darstellung für Claude-Antworten
struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // SwiftUI's Text unterstützt AttributedString mit Markdown
            if let attributed = try? AttributedString(markdown: text,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )) {
                Text(attributed)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.body)
    }
}
