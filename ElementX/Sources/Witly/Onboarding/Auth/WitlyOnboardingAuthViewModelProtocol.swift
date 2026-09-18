//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol WitlyOnboardingAuthViewModelProtocol {
    var actionsPublisher: AnyPublisher<WitlyOnboardingAuthViewModelAction, Never> { get }
    var context: WitlyOnboardingAuthViewModelType.Context { get }
}
