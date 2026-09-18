//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

struct WitlyOnboardingConnectCoordinatorParameters {
    let witlySession: WitlySession
}

enum WitlyOnboardingConnectCoordinatorAction {
    case finished
}

/// The final onboarding step: connect WhatsApp (phone number → pairing code), or skip for now.
/// Other platforms are shown as "coming soon" — their bridges don't exist yet.
final class WitlyOnboardingConnectCoordinator: CoordinatorProtocol {
    private let viewModel: WitlyOnboardingConnectViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<WitlyOnboardingConnectCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<WitlyOnboardingConnectCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: WitlyOnboardingConnectCoordinatorParameters) {
        viewModel = WitlyOnboardingConnectViewModel(witlySession: parameters.witlySession)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            switch action {
            case .finished:
                self?.actionsSubject.send(.finished)
            }
        }
        .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(WitlyOnboardingConnectScreen(context: viewModel.context))
    }
}
