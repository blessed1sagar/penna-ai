//
//  ContentView.swift
//  Penna
//
//  Holds PanelView — the UI that drops down from the menu-bar icon.
//

import SwiftUI
import AppKit
import OllamaKit

/// The Panel that opens from the menu-bar icon. The layout is the issue #9 shell;
/// issue #10 wires it to the brain and the clipboard via PanelModel.
struct PanelView: View {
    // All Panel state and behaviour (input, result, errors, auto-fill, run,
    // auto-copy) lives in PanelModel from the OllamaKit package, so it's the same
    // tested logic — not a copy hand-written in the view (ADR-0007). @StateObject:
    // the view owns one instance for its lifetime and re-renders when it changes.
    @StateObject private var model = PanelModel()

    private var inputIsBlank: Bool {
        model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            TextEditor(text: $model.input)
                .font(.body)
                .frame(minHeight: 100)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.secondary.opacity(0.3))
                )

            // Run button — sends the input to the model. ⌘↵ runs it too. Disabled
            // on blank input so an empty run never reaches the model.
            Button("Run") {
                Task { await model.run() }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(inputIsBlank)

            // A clear error (e.g. Ollama not running) instead of a hang or crash.
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            // Result area — the model's corrected text (also Auto-copied).
            ScrollView {
                Text(model.result)
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
        // Clipboard auto-fill: when the Panel opens, prefill the input from the
        // clipboard (Improve only, enforced inside the model).
        .onAppear { model.prefillFromClipboard() }
    }
}

#Preview {
    PanelView()
}
