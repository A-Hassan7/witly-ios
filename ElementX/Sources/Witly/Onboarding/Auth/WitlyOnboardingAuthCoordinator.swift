//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

struct WitlyOnboardingAuthCoordinatorParameters {
    let witlySession: WitlySession
    let presentationAnchor: UIWindow
}

enum WitlyOnboardingAuthCoordinatorAction {
    case authenticated
}

final class WitlyOnboardingAuthCoordinator: CoordinatorProtocol {
    private let viewModel: WitlyOnboardingAuthViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<WitlyOnboardingAuthCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<WitlyOnboardingAuthCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: WitlyOnboardingAuthCoordinatorParameters) {
        viewModel = WitlyOnboardingAuthViewModel(witlySession: parameters.witlySession,
                                                 presentationAnchor: parameters.presentationAnchor)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            switch action {
            case .authenticated:
                self?.actionsSubject.send(.authenticated)
            }
        }
        .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(WitlyOnboardingAuthScreen(context: viewModel.context))
    }
}
