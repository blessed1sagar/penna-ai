import Testing
@testable import OllamaKit

// Slice 1 (tracer bullet): a freshly-opened Panel starts in Improve mode.
// ADR-0006 lists three modes (Improve / Rephrase / Draft); Improve is the
// default because it's the most common, lowest-risk action (minimal correction).
@Test @MainActor func panelStartsInImproveMode() {
    let model = PanelModel()

    #expect(model.selectedMode == .improve)
}

// Slice 2: the selector offers exactly the three modes, in display order. The
// UI builds its segmented control from Mode.allCases, so the order lives here
// (one source of truth) rather than being hand-typed in the SwiftUI view.
@Test func modesAreOfferedInDisplayOrder() {
    #expect(Mode.allCases == [.improve, .rephrase, .draft])
}

// Slice 3: each mode carries its own button label, so the selector reads its
// titles from the model instead of hard-coding strings in the SwiftUI view.
@Test func eachModeHasADisplayTitle() {
    #expect(Mode.improve.title == "Improve")
    #expect(Mode.rephrase.title == "Rephrase")
    #expect(Mode.draft.title == "Draft")
}
