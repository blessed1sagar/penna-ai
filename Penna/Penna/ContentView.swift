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
    // tested logic — not a copy hand-written in the view (ADR-0007). The model is
    // owned by MenuBarController and injected here, so it survives the Panel being
    // hidden/reshown (the controller refreshes the clipboard on each open) — the
    // view is built once, which also avoids an AppKit layout-recursion warning.
    @ObservedObject private var model: PanelModel

    init(model: PanelModel) {
        self.model = model
    }

    private var inputIsBlank: Bool {
        model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mode selector — built from Mode.allCases so the list and its order
            // come from the package, not hard-coded here. Improve is preselected.
            // The setter defers the whole mode switch to the next main-actor turn
            // before it touches the model. SwiftUI invokes this setter while it is
            // mid view-update — the segmented control commits the selection during
            // the panel's layout pass — and selectMode() mutates @Published state
            // (selectedMode AND input). Mutating inline, whether through this binding
            // or a direct $model.selectedMode binding, trips "Publishing changes from
            // within view updates"; hopping a turn moves every mutation cleanly after
            // the render (issue #25). The selection shows ~one frame late, invisibly.
            Picker("Mode", selection: Binding(
                get: { model.selectedMode },
                set: { newMode in
                    Task { @MainActor in model.selectMode(newMode) }
                }
            )) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Editable multiline input box. When empty, it shows the current
            // mode's placeholder (e.g. Draft's "Tell me what to write…"), read
            // from the model so the copy lives in one place.
            TextEditor(text: $model.input)
                .font(.body)
                .frame(minHeight: 100)
                .padding(4)
                .overlay(alignment: .topLeading) {
                    if inputIsBlank {
                        Text(model.selectedMode.placeholder)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
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
        // Clipboard auto-fill (prefill the input from the clipboard, Improve only)
        // is driven by MenuBarController on every open, not via .onAppear here —
        // the view is reused across opens, so .onAppear would fire only once.
    }
}

#Preview {
    PanelView(model: PanelModel())
}
