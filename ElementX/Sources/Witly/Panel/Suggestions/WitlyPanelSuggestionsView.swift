//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// The panel's Suggestions tab (product-spec §7.3): the full current suggestion set, regenerate,
/// and a custom-intent field so the user can steer generation ("tell them I'm running late") instead
/// of only reacting to whatever the carousel produced automatically. Tapping a suggestion here does
/// the same thing as tapping a carousel card — inserts it as an editable composer draft, never sends
/// — and additionally dismisses the sheet so the user lands back in the composer to finish it.
struct WitlyPanelSuggestionsView: View {
    @ObservedObject var viewModel: WitlyRoomSuggestionsViewModel
    @State private var intentText = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isIntentFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    suggestionsSection
                }
                .padding(16)
            }
            Divider()
            intentBar
        }
    }
    
    @ViewBuilder
    private var suggestionsSection: some View {
        switch viewModel.state.phase {
        case .idle:
            Text("No suggestions yet — describe what you want to say below, or wait for the next message.")
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textSecondary)
        case .generating:
            HStack(spacing: 8) {
                ProgressView()
                Text("Cooking up some replies…")
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
            }
        case .streaming, .ready:
            ForEach(viewModel.state.suggestions) { suggestion in
                suggestionRow(suggestion)
            }
            if viewModel.state.phase == .ready {
                regenerateButton
            }
        case .error(let message):
            Text(message)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textSecondary)
            regenerateButton
        }
    }
    
    private func suggestionRow(_ suggestion: WitlySuggestion) -> some View {
        Button {
            viewModel.insertSuggestion(suggestion)
            dismiss()
        } label: {
            Text(suggestion.text)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .witlySuggestionCardBackground(cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Insert as a draft in the composer")
    }
    
    private var regenerateButton: some View {
        Button {
            viewModel.regenerate()
        } label: {
            Label("Regenerate", systemImage: "arrow.clockwise")
                .font(.compound.bodySMSemibold)
                .foregroundStyle(WitlyBrand.colorScheme.accent)
        }
        .buttonStyle(.plain)
    }
    
    private var intentBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("What do you want to say?", text: $intentText, axis: .vertical)
                .font(.compound.bodyMD)
                .lineLimit(1...4)
                .focused($isIntentFieldFocused)
                .padding(10)
                .background(Color.compound.bgSubtleSecondaryLevel0, in: RoundedRectangle(cornerRadius: 12))
            
            Button(action: submitIntent) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSubmitIntent
                        ? WitlyBrand.colorScheme.accent : Color.compound.iconDisabled)
            }
            .disabled(!canSubmitIntent)
        }
        .padding(12)
    }
    
    private var canSubmitIntent: Bool {
        !intentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func submitIntent() {
        let intent = intentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !intent.isEmpty else { return }
        viewModel.generate(customIntent: intent)
        intentText = ""
        isIntentFieldFocused = false
    }
}
