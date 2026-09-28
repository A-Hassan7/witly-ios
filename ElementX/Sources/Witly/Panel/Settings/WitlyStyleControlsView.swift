//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// The panel's Settings tab: response-style controls (Boldness/Flirt/Bluntness/Dryness) that steer
/// "Me + Wittier" — never a replacement for the user's own voice. Rendered entirely from backend
/// metadata (`WitlyRoomSuggestionsViewModel.styleControls`, sourced from `GET /ai/catalog`'s active
/// prompt) rather than a hardcoded roster, per product-spec: the frontend only ever sees
/// id/name/description/default/options, never the prompt-injection text behind each option.
///
/// "Custom for this chat" mirrors the mental model in the task spec — Me + Wittier uses the same
/// global style everywhere by default; turning this on lets the current conversation diverge without
/// touching any other chat, and turning it back off is a one-tap return to the global default.
struct WitlyStyleControlsView: View {
    @ObservedObject var viewModel: WitlyRoomSuggestionsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                overrideToggle
                
                if viewModel.styleControls.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(viewModel.styleControls) { control in
                            controlRow(control)
                        }
                    }
                }
            }
            .padding(16)
        }
        .task {
            viewModel.loadStyleControlsIfNeeded()
        }
    }
    
    private var overrideToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(get: { viewModel.hasRoomStyleOverride },
                                 set: { isOn in
                                     if isOn {
                                         viewModel.enableRoomStyleOverride()
                                     } else {
                                         viewModel.resetRoomStyleOverrides()
                                     }
                                 })) {
                Text("Custom for this chat")
                    .font(.compound.bodyMDSemibold)
                    .foregroundStyle(.compound.textPrimary)
            }
            .tint(WitlyBrand.colorScheme.accent)
            
            Text("Off applies your usual Me + Wittier style everywhere. On lets you tune it just for this conversation.")
                .font(.compound.bodyXS)
                .foregroundStyle(.compound.textSecondary)
        }
    }
    
    private func controlRow(_ control: WitlyStyleControl) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(control.name)
                .font(.compound.bodyMDSemibold)
                .foregroundStyle(.compound.textPrimary)
            Text(control.description)
                .font(.compound.bodyXS)
                .foregroundStyle(.compound.textSecondary)
            
            Picker(control.name, selection: Binding(get: { viewModel.effectiveStyleValue(for: control) },
                                                    set: { optionID in
                                                        if viewModel.hasRoomStyleOverride {
                                                            viewModel.setRoomStyleValue(controlID: control.id, optionID: optionID)
                                                        } else {
                                                            viewModel.setGlobalStyleValue(controlID: control.id, optionID: optionID)
                                                        }
                                                    })) {
                ForEach(control.options) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
