//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// The Witly bottom sheet (product-spec §7.3): the deeper, deliberate control surface behind the ✨
/// button, distinct from the always-visible carousel above the composer. Presented as a native sheet
/// from `WitlySuggestionsBarContainer` — see `PATCHES.md` for why no new core seam was needed.
///
/// This pass wires up Suggestions (view/regenerate/custom-intent) and Settings (response-style
/// controls) fully; Ask AI and Wits are placeholder shells (out of scope for this milestone).
struct WitlyPanelView: View {
    @ObservedObject var viewModel: WitlyRoomSuggestionsViewModel
    @State private var selectedTab: WitlyPanelTab = .suggestions
    
    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider()
            content
        }
        .background(Color.compound.bgCanvasDefault)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var tabStrip: some View {
        HStack(spacing: 0) {
            ForEach(WitlyPanelTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.top, 8)
    }
    
    private func tabButton(_ tab: WitlyPanelTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(tab.title)
                    .font(.compound.bodyXS)
            }
            .foregroundStyle(selectedTab == tab ? WitlyBrand.colorScheme.accent : Color.compound.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                if selectedTab == tab {
                    Capsule()
                        .fill(WitlyBrand.colorScheme.accent)
                        .frame(height: 2)
                        .padding(.horizontal, 24)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
    }
    
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .suggestions:
            WitlyPanelSuggestionsView(viewModel: viewModel)
        case .askAI:
            WitlyPanelPlaceholderView(title: "Ask AI",
                                      message: "Ask Witly questions about this chat. Coming soon.",
                                      systemImage: "bubble.left.and.bubble.right")
        case .wits:
            WitlyPanelPlaceholderView(title: "Wits",
                                      message: "Browse and manage Witly personas. Coming soon.",
                                      systemImage: "person.2")
        case .settings:
            WitlyStyleControlsView(viewModel: viewModel)
        }
    }
}

/// A reusable "not built yet" shell for panel tabs out of scope this pass, so the tab strip is real
/// and navigable without pretending the feature exists.
struct WitlyPanelPlaceholderView: View {
    let title: String
    let message: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(.compound.iconSecondary)
            Text(title)
                .font(.compound.headingSMSemibold)
                .foregroundStyle(.compound.textPrimary)
            Text(message)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
