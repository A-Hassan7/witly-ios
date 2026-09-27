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
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            witlyButton
            
            switch state.phase {
            case .idle:
                EmptyView()
            case .generating:
                generatingContent
            case .streaming, .ready:
                suggestionsContent
            case .error(let message):
                errorContent(message)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isCollapsed ? 6 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.compound.bgCanvasDefault)
        .animation(.default, value: state)
    }
    
    private var isCollapsed: Bool {
        state.phase == .idle
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
            HStack(spacing: 8) {
                ForEach(state.suggestions) { suggestion in
                    WitlySuggestionChip(suggestion: suggestion) {
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
    }
    
    private var regenerateButton: some View {
        Button(action: onRegenerate) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.compound.iconSecondary)
                .frame(width: 32, height: 32)
                .background(Color.compound.bgSubtleSecondaryLevel0, in: Circle())
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

/// One compact, horizontally-scrolling suggestion card. Text-first; no source/persona label, model
/// name, or confidence score (product-spec §7.1 / DRIVE-C4).
private struct WitlySuggestionChip: View {
    let suggestion: WitlySuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(suggestion.text)
                .font(.compound.bodySM)
                .foregroundColor(.compound.textPrimary)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 220, alignment: .leading)
                .background(Color.compound.bgSubtleSecondaryLevel0, in: RoundedRectangle(cornerRadius: 14))
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
