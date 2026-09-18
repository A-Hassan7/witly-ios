//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Mirrors the web fork's `ConnectDialog` state machine: picker → preparing → phone → pairing →
/// connected. iOS only offers WhatsApp today; other platforms are shown as "coming soon".
enum WitlyOnboardingConnectPhase: Equatable {
    case picker
    case preparing
    case phone
    case pairing
    case connected
}

struct WitlyOnboardingConnectViewState: BindableState {
    var phase: WitlyOnboardingConnectPhase = .picker
    var prepareDetail = "Hang tight — magic in progress"
    var errorMessage: String?
    var pairingCode: String?
    var isLoading = false
    
    var bindings: WitlyOnboardingConnectViewStateBindings
}

struct WitlyOnboardingConnectViewStateBindings {
    var phoneNumber = "+44"
}

enum WitlyOnboardingConnectViewAction {
    case connectWhatsApp
    case skip
    case retryPrepare
    case submitPhone
    case startOver
    case finish
}

enum WitlyOnboardingConnectViewModelAction {
    /// The user is done with this step, whether they connected a platform or skipped.
    case finished
}
