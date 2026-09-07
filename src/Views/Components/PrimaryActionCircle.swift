import SwiftUI

struct PrimaryActionCircle: View {
    let title: String
    let isBreathing: Bool
    var isHovering: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isBreathing && !reduceMotion {
            BreathingPrimaryActionCircle(title: title)
        } else {
            StaticPrimaryActionCircle(title: title, isHovering: isHovering)
        }
    }
}

private struct BreathingPrimaryActionCircle: View {
    let title: String
    @State private var isExpanded = false

    var body: some View {
        PrimaryActionCircleBase(
            title: title,
            scale: isExpanded ? 1.04 : 1,
            rotation: isExpanded ? 0.4 : 0,
            shadowOpacity: isExpanded ? 0.36 : 0.24,
            shadowRadius: isExpanded ? 18 : 12
        )
        .animation(
            .easeInOut(duration: 1.25).repeatForever(autoreverses: true),
            value: isExpanded
        )
        .onAppear {
            isExpanded = true
        }
    }
}

private struct StaticPrimaryActionCircle: View {
    let title: String
    let isHovering: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PrimaryActionCircleBase(
            title: title,
            scale: isHovering ? 1.02 : 1,
            rotation: 0,
            shadowOpacity: isHovering ? 0.42 : 0.22,
            shadowRadius: isHovering ? 17 : 11
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: isHovering
        )
    }
}

private struct PrimaryActionCircleBase: View {
    let title: String
    let scale: CGFloat
    let rotation: Double
    let shadowOpacity: Double
    let shadowRadius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.theme.primaryAction)
                .overlay {
                    Circle()
                        .stroke(Color.theme.primaryActionForeground.opacity(0.22), lineWidth: 0.5)
                }
                .shadow(
                    color: Color.theme.primaryAction.opacity(shadowOpacity),
                    radius: shadowRadius,
                    y: 6
                )

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.theme.primaryActionForeground)
        }
        .frame(width: 116, height: 116)
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
    }
}
