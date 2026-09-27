//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI

/// Binds a live `WitlyRoomSuggestionsViewModel` to the presentational `WitlySuggestionsBarView`.
/// Kept as its own tiny type so `RoomScreen.swift`'s seam is a single, trivial line (see `PATCHES.md`).
struct WitlySuggestionsBarContainer: View {
    @ObservedObject var viewModel: WitlyRoomSuggestionsViewModel
    
    var body: some View {
        WitlySuggestionsBarView(state: viewModel.state,
                                onTapSuggestion: viewModel.insertSuggestion,
                                onRegenerate: viewModel.regenerate,
                                onOpenWitly: viewModel.openWitly)
    }
}
