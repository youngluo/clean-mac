import SwiftUI

struct PrimaryActionCircle: View {
    let title: String
    let isWorking: Bool
    var isHovering: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private var workingAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return isAnimating
            ? .easeInOut(duration: 1.25).repeatForever(autoreverses: true)
            : .easeOut(duration: 0.2)
    }

    private var circleScale: CGFloat {
        if isAnimating { return 1.04 }
        return isHovering ? 1.02 : 1
    }

    private var shadowOpacity: Double {
        if isWorking { return isAnimating ? 0.36 : 0.24 }
        return isHovering ? 0.42 : 0.22
    }

    private var shadowRadius: CGFloat {
        if isWorking { return isAnimating ? 18 : 12 }
        return isHovering ? 17 : 11
    }

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
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.2),
                    value: isHovering
                )
                .animation(workingAnimation, value: isAnimating)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.theme.primaryActionForeground)
        }
        .frame(width: 116, height: 116)
        .scaleEffect(circleScale)
        .rotationEffect(.degrees(isAnimating ? 0.4 : 0))
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: isHovering
        )
        .animation(workingAnimation, value: isAnimating)
        .onAppear {
            isAnimating = isWorking && !reduceMotion
        }
        .onChange(of: isWorking) { _ in
            isAnimating = isWorking && !reduceMotion
        }
        .onChange(of: reduceMotion) { _ in
            isAnimating = isWorking && !reduceMotion
        }
    }
}
