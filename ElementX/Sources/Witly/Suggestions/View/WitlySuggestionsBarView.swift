//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// The compact Witly suggestion surface, mounted directly above the standard composer
/// (`RoomScreen.swift`, `// WITLY SEAM`). Purely presentational — driven by `WitlyRoomSuggestionsState`
/// and a handful of callbacks so it stays trivially previewable/testable without any networking or
/// timeline dependency (see `WitlySuggestionsBarContainer` for the live `ObservableObject` wiring).
///
/// Per product-spec §7.1 / DRIVE-C4: suggestion text is the focus. No model names, confidence scores,
/// technical metadata, or large persona/source labels are ever shown here.
struct WitlySuggestionsBarView: View {
    let state: WitlyRoomSuggestionsState
    /// Tapping a card inserts it into the composer as an editable draft — never sends.
    let onTapSuggestion: (WitlySuggestion) -> Void
    let onRegenerate: () -> Void
    /// The ✨ button: opens the deeper Witly surface. Conceptually distinct from regenerate — see
    /// `WitlyRoomSuggestionsViewModel.onOpenWitly`.
    let onOpenWitly: () -> Void
    
    /// The bar's own width, used to cap each card at 40% of it so medium-length replies stay
    /// readable without the carousel becoming a full-width panel. Seeded with a plausible
    /// pre-layout guess so cards don't flash oversized before the first `readWidth` measurement.
    @State private var availableWidth: CGFloat = 320
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            witlyButton
            
            switch state.phase {
            case .idle:
                suggestButton
            case .generating:
                generatingContent
            case .streaming, .ready:
                suggestionsContent
            case .error(let message):
                errorContent(message)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .readWidth($availableWidth)
        .background(Color.compound.bgCanvasDefault)
        .animation(.default, value: state)
    }
    
    private var witlyButton: some View {
        Button(action: onOpenWitly) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WitlyBrand.colorScheme.accent)
                .frame(width: 32, height: 32)
                .background(WitlyBrand.colorScheme.accent.opacity(0.12), in: Circle())
        }
        .accessibilityLabel("Witly")
    }
    
    /// Idle-state manual trigger — the only way to request a first round of suggestions before any
    /// inbound message has fired the Smart-timing auto-trigger. Shares `onRegenerate` with the
    /// ready/error states' refresh affordances: there's exactly one "give me suggestions now" action,
    /// available in every phase. Styled as a pill (not plain text) so it reads as tappable rather
    /// than as a caption for `witlyButton`.
    private var suggestButton: some View {
        Button(action: onRegenerate) {
            Text("Suggest replies")
                .font(.compound.bodySMSemibold)
                .foregroundStyle(WitlyBrand.colorScheme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(WitlyBrand.colorScheme.accent.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var generatingContent: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Cooking up some replies…")
                .font(.compound.bodySM)
                .foregroundColor(.compound.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
    
    private var suggestionsContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 8) {
                ForEach(state.suggestions) { suggestion in
                    WitlySuggestionChip(suggestion: suggestion, maxWidth: availableWidth * 0.4) {
                        onTapSuggestion(suggestion)
                    }
                }
                
                if state.phase == .streaming {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 4)
                } else {
                    regenerateButton
                }
            }
        }
        // Must be on the ScrollView itself: a horizontal ScrollView otherwise reports a minimal
        // height to its parent and clips taller (wrapped, multi-line) cards. This makes it adopt
        // its content's ideal height so the row grows to fit 2–3 line cards.
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private var regenerateButton: some View {
        Button(action: onRegenerate) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.compound.iconSecondary)
                .frame(width: 32, height: 32)
                // Not bgSubtleSecondaryLevel0: it's identical to bgCanvasDefault in dark mode, so the
                // button became invisible against the bar's own background.
                .background(Color.compound.bgSubtlePrimary, in: Circle())
        }
        .accessibilityLabel("Regenerate suggestions")
    }
    
    private func errorContent(_ message: String) -> some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.compound.bodySM)
                .foregroundColor(.compound.textSecondary)
                .lineLimit(1)
            Button(L10n.actionRetry, action: onRegenerate)
                .font(.compound.bodySMSemibold)
                .foregroundStyle(WitlyBrand.colorScheme.accent)
        }
    }
}

/// One horizontally-scrolling suggestion card. Text-first; no source/persona label, model name, or
/// confidence score (product-spec §7.1 / DRIVE-C4). Wraps up to 3 lines and is capped at 40% of the
/// bar's width, so medium-length replies stay readable without the carousel becoming a full panel.
private struct WitlySuggestionChip: View {
    let suggestion: WitlySuggestion
    let maxWidth: CGFloat
    let onTap: () -> Void
    
    /// The text's natural (unwrapped) single-line width, computed synchronously from font metrics
    /// rather than a runtime geometry measurement — `ForEach` keeps this chip's view identity
    /// across regenerations (same `suggestion.id`), so a `@State`-based measurement doesn't reset
    /// when `suggestion.text` changes for that id and can render a stale width for the new text.
    /// `min(naturalWidth, maxWidth)` shrinks short cards, still caps long ones at `maxWidth`.
    private var cardWidth: CGFloat {
        min(Self.naturalTextWidth(suggestion.text) + 24, maxWidth) // 24 = 12pt horizontal padding × 2
    }
    
    private static func naturalTextWidth(_ text: String) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .footnote) // matches .compound.bodySM
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(suggestion.text)
                .font(.compound.bodySM)
                .foregroundColor(.compound.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                // Rigid width BEFORE fixedSize so the height is measured at the exact width the
                // card renders at — `frame(maxWidth:)` alone doesn't reliably force `Text` to wrap
                // inside this unconstrained-width horizontal ScrollView, which is what was cropping
                // taller cards.
                .frame(width: cardWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                // Stretch to the row's height (the tallest sibling card) so every card is the same
                // height; `.leading` centres vertically while keeping the text left-aligned.
                .frame(maxHeight: .infinity, alignment: .leading)
                // Not bgSubtleSecondaryLevel0: it's identical to bgCanvasDefault in dark mode
                // (#101317 == #101317), which made adjacent cards indistinguishable from each other
                // and from the bar's own background. bgSubtlePrimary is genuinely distinct in both
                // appearances; the border adds definition between cards regardless of theme.
                .background(Color.compound.bgSubtlePrimary, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.compound.borderInteractiveSecondary, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(suggestion.text))
        .accessibilityHint("Insert as a draft in the composer")
    }
}

// MARK: - Previews

struct WitlySuggestionsBarView_Previews: PreviewProvider, TestablePreview {
    static let sampleSuggestions = [
        WitlySuggestion(id: 0, text: "Haha no way, tell me everything", tone: "casual"),
        WitlySuggestion(id: 1, text: "Bold of you to assume I wasn't already on my way", tone: "banter"),
        WitlySuggestion(id: 2, text: "Sure, let me just drop everything for this 🙄", tone: "sarcastic")
    ]
    
    static var previews: some View {
        Group {
            WitlySuggestionsBarView(state: .idle, onTapSuggestion: { _ in }, onRegenerate: { }, onOpenWitly: { })
                .previewDisplayName("Idle")
            
            WitlySuggestionsBarView(state: .init(phase: .generating, suggestions: []),
                                    onTapSuggestion: { _ in }, onRegenerate: { }, onOpenWitly: { })
                .previewDisplayName("Generating")
            
            WitlySuggestionsBarView(state: .init(phase: .streaming, suggestions: [sampleSuggestions[0]]),
                                    onTapSuggestion: { _ in }, onRegenerate: { }, onOpenWitly: { })
                .previewDisplayName("Streaming (first card)")
            
            WitlySuggestionsBarView(state: .init(phase: .ready, suggestions: sampleSuggestions),
                                    onTapSuggestion: { _ in }, onRegenerate: { }, onOpenWitly: { })
                .previewDisplayName("Ready")
            
            WitlySuggestionsBarView(state: .init(phase: .error(message: "Couldn't get suggestions right now."), suggestions: []),
                                    onTapSuggestion: { _ in }, onRegenerate: { }, onOpenWitly: { })
                .previewDisplayName("Error")
        }
        .padding(.vertical, 8)
        .previewLayout(.sizeThatFits)
    }
}
