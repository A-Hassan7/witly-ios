//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

enum WitlyOnboardingIntroCoordinatorAction {
    case getStarted
    case signIn
}

/// The first screen of Witly onboarding: value proposition + a placeholder for the product demo
/// video, matching `docs/witly/figma-mobile-handover/src/app/components/OnboardingValueIntro.tsx`.
/// This is a single screen (no swipeable carousel) — the video slot is a placeholder until the
/// product video is ready.
final class WitlyOnboardingIntroCoordinator: CoordinatorProtocol {
    private let actionsSubject: PassthroughSubject<WitlyOnboardingIntroCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<WitlyOnboardingIntroCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    func toPresentable() -> AnyView {
        AnyView(WitlyOnboardingIntroScreen(onGetStarted: { [weak self] in
            self?.actionsSubject.send(.getStarted)
        }, onSignIn: { [weak self] in
            self?.actionsSubject.send(.signIn)
        }))
    }
}
