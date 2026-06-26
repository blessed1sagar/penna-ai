//
//  ContentView.swift
//  Penna
//
//  Holds PanelView — the UI that drops down from the menu-bar icon.
//

import SwiftUI
import AppKit
import OllamaKit

/// The Panel that opens from the menu-bar icon. This is the issue #9 shell:
/// the full layout is here, but nothing is wired to the model yet — wiring the
/// brain and the clipboard is issue #10.
struct PanelView: View {
    // Panel state lives in PanelModel (from the OllamaKit package), so the
    // selected mode and its Improve default are the same tested logic, not a
    // copy hand-written in the view.
    @State private var model = PanelModel()

    // The text being worked on and the model's result. Plain UI state for now;
    // #10 fills `input` from the clipboard (Improve/Rephrase) and `result` from Ollama.
    @State private var input = ""
    @State private var result = ""

    private var inputIsBlank: Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mode selector — built from Mode.allCases so the list and its order
            // come from the package, not hard-coded here. Improve is preselected.
            Picker("Mode", selection: $model.selectedMode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Editable multiline input box.
            TextEditor(text: $input)
                .font(.body)
                .frame(minHeight: 100)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.secondary.opacity(0.3))
                )

            // Run button — present but inert in this slice. ⌘↵ runs it too.
            Button("Run") {
                // TODO(#10): call the selected mode's brain and show the result.
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(inputIsBlank)

            // Result area — empty for now; #10 fills it with the model's output.
            ScrollView {
                Text(result)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.secondary.opacity(0.3))
            )

            // Footer with Quit. A Dock-less menu-bar app has no Dock icon or
            // window close-button, so this (and ⌘Q) is the only way to exit.
            HStack {
                Spacer()
                Button("Quit Penna") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 360)
    }
}

#Preview {
    PanelView()
}
