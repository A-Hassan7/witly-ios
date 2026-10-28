//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI
import UIKit

/// A room timeline's background, behind the message bubbles. Adding a new kind of background (e.g.
/// an image) is a new case here plus a render branch in `WitlyRoomBackgroundView` — no changes to
/// `WitlyColorScheme`, `WitlyThemeStore`, or `TimelineTableViewController` are needed.
enum WitlyRoomBackground: Sendable, Equatable {
    /// Defers to Compound's own canvas-default background — the vanilla Element X look.
    case defaultCanvas
    case solid(Color)
    /// `angleDegrees` follows standard compass convention: 0 = left-to-right, 90 = top-to-bottom.
    case gradient(colors: [Color], angleDegrees: Double)
    case pattern(WitlyBackgroundPattern, tint: Color)
}

/// A procedurally-drawn background pattern (no image assets required). Add a case here and a draw
/// branch in `WitlyBackgroundPattern.draw(in:size:tint:)` to introduce a new one.
enum WitlyBackgroundPattern: String, Sendable, Equatable, CaseIterable {
    case dots
    case grid
}

/// Renders a `WitlyRoomBackground` as SwiftUI content.
struct WitlyRoomBackgroundView: View {
    let background: WitlyRoomBackground
    
    var body: some View {
        switch background {
        case .defaultCanvas:
            Color.compound.bgCanvasDefault
        case .solid(let color):
            color
        case .gradient(let colors, let angleDegrees):
            LinearGradient(colors: colors,
                           startPoint: Self.unitPoint(forAngle: angleDegrees),
                           endPoint: Self.unitPoint(forAngle: angleDegrees + 180))
        case .pattern(let pattern, let tint):
            ZStack {
                Color.compound.bgCanvasDefault
                Canvas { context, size in
                    pattern.draw(in: &context, size: size, tint: tint)
                }
            }
        }
    }
    
    private static func unitPoint(forAngle degrees: Double) -> UnitPoint {
        let radians = degrees * .pi / 180
        return UnitPoint(x: 0.5 + 0.5 * cos(radians), y: 0.5 + 0.5 * sin(radians))
    }
}

private extension WitlyBackgroundPattern {
    func draw(in context: inout GraphicsContext, size: CGSize, tint: Color) {
        let spacing: CGFloat = 24
        switch self {
        case .dots:
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                                 with: .color(tint.opacity(0.25)))
                    y += spacing
                }
                x += spacing
            }
        case .grid:
            var path = Path()
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(tint.opacity(0.15)), lineWidth: 0.5)
        }
    }
}

extension WitlyRoomBackground {
    /// A UIKit-hostable view for `UITableView.backgroundView` — the timeline is UIKit, not SwiftUI
    /// (see `TimelineTableViewController`). Counter-rotates the hosting view since the table itself
    /// is flipped 180° to anchor newest messages at the bottom, so directional gradients/patterns
    /// render the right way up instead of mirrored.
    @MainActor
    func makeBackgroundView() -> UIView {
        let host = UIHostingController(rootView: WitlyRoomBackgroundView(background: self))
        host.view.transform = CGAffineTransform(scaleX: 1, y: -1)
        host.view.backgroundColor = .clear
        return host.view
    }
}
