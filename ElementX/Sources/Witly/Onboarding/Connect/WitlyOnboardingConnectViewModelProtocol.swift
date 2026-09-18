//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

@MainActor
protocol WitlyOnboardingConnectViewModelProtocol {
    var actionsPublisher: AnyPublisher<WitlyOnboardingConnectViewModelAction, Never> { get }
    var context: WitlyOnboardingConnectViewModelType.Context { get }
}
