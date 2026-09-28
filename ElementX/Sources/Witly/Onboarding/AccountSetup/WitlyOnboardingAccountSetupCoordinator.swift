//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SwiftUI

/// The "account setup" waiting state (I2-2): shown only when the account isn't ready yet by the
/// time auth completes, right before "Connect your chats". Purely presentational — the flow
/// coordinator drives the transition onward once provisioning finishes. No Matrix/homeserver
/// terminology, no percentage/timers, no CTA.
final class WitlyOnboardingAccountSetupCoordinator: CoordinatorProtocol {
    func toPresentable() -> AnyView {
        AnyView(WitlyOnboardingAccountSetupScreen())
    }
}
