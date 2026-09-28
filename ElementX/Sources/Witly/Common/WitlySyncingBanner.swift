//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// I2-1: a restrained, informational "still catching up on history" notice — distinct from an
/// error/reconnect state (neutral styling, no warning colours, no action required).
struct WitlySyncingBanner: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.compound.bodySM)
                .foregroundColor(.compound.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.compound.bgCanvasDefault)
    }
}
