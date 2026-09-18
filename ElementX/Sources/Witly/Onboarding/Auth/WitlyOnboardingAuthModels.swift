//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

/// Which step of the sign-in flow is currently shown.
enum WitlyOnboardingAuthMode: Equatable {
    case chooser
    case emailCode(email: String)
    case phoneCode(phone: String)
}

struct WitlyOnboardingAuthViewState: BindableState {
    var mode: WitlyOnboardingAuthMode = .chooser
    var isLoading = false
    var errorMessage: String?
    
    var bindings: WitlyOnboardingAuthViewStateBindings
}

struct WitlyOnboardingAuthViewStateBindings {
    var emailAddress = ""
    var phoneNumber = ""
    var code = ""
}

enum WitlyOnboardingAuthViewAction {
    case continueWithGoogle
    case sendEmailCode
    case verifyEmailCode
    case sendPhoneCode
    case verifyPhoneCode
    case goBack
}

enum WitlyOnboardingAuthViewModelAction {
    /// The user has successfully signed in with Supabase; the `WitlySession` has been established.
    case authenticated
}
