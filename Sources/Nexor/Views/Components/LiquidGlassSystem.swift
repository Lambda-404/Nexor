#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Native NSVisualEffectView Translucency Wrapper

public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .underWindowBackground,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Ambient Fluid Liquid Mesh Background

public struct LiquidAmbientMesh: View {
    @State private var animateGlow: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Base window visual effect
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
            
            // Subtle ambient dynamic fluid orbs
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                
                // Top-leading cyan liquid glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.0, green: 0.85, blue: 1.0).opacity(animateGlow ? 0.09 : 0.05),
                                Color(red: 0.1, green: 0.5, blue: 1.0).opacity(0.02),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(w, h) * 0.45
                        )
                    )
                    .frame(width: max(w, h) * 0.9, height: max(w, h) * 0.9)
                    .position(x: w * 0.15, y: h * 0.1)
                    .blur(radius: 60)
                
                // Bottom-trailing indigo / violet liquid glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.45, green: 0.2, blue: 1.0).opacity(animateGlow ? 0.08 : 0.04),
                                Color(red: 0.2, green: 0.35, blue: 0.9).opacity(0.02),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(w, h) * 0.5
                        )
                    )
                    .frame(width: max(w, h), height: max(w, h))
                    .position(x: w * 0.85, y: h * 0.85)
                    .blur(radius: 70)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}

// MARK: - Liquid Glass Container Modifiers

public struct LiquidGlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var isHighlighted: Bool
    public var elevation: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        cornerRadius: CGFloat = 16,
        isHighlighted: Bool = false,
        elevation: CGFloat = 2
    ) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.elevation = elevation
    }
    
    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Subtle adaptive glass sheen
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                isHighlighted
                                ? Color.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.08)
                                : (colorScheme == .dark ? Color.white.opacity(0.035) : Color.white.opacity(0.45))
                            )
                    }
                    .overlay {
                        // Hairline specular gradient border
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: isHighlighted
                                    ? [
                                        Color.accentColor.opacity(0.7),
                                        Color.accentColor.opacity(0.3),
                                        Color.cyan.opacity(0.4)
                                    ]
                                    : [
                                        Color.white.opacity(colorScheme == .dark ? 0.25 : 0.5),
                                        Color.white.opacity(colorScheme == .dark ? 0.06 : 0.2),
                                        Color.white.opacity(colorScheme == .dark ? 0.02 : 0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: isHighlighted
                        ? Color.accentColor.opacity(0.18)
                        : Color.black.opacity(colorScheme == .dark ? 0.20 : 0.06),
                        radius: elevation * 4,
                        x: 0,
                        y: elevation * 2
                    )
            }
    }
}

public extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 16,
        isHighlighted: Bool = false,
        elevation: CGFloat = 2
    ) -> some View {
        modifier(LiquidGlassCardModifier(
            cornerRadius: cornerRadius,
            isHighlighted: isHighlighted,
            elevation: elevation
        ))
    }
}

// MARK: - Liquid Glass Badge & Pill

public struct LiquidGlassPill: View {
    public let text: String
    public var icon: String?
    public var color: Color
    public var isFilled: Bool
    
    public init(
        text: String,
        icon: String? = nil,
        color: Color = .secondary,
        isFilled: Bool = false
    ) {
        self.text = text
        self.icon = icon
        self.color = color
        self.isFilled = isFilled
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background {
            if isFilled {
                Capsule(style: .continuous)
                    .fill(color.opacity(0.18))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(color.opacity(0.35), lineWidth: 0.8)
                    }
            } else {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(color.opacity(0.35), lineWidth: 0.8)
                    }
            }
        }
    }
}

// MARK: - Pulsing Beacon for Real-Time Discovery Cues

public struct PulsingBeacon: View {
    public let color: Color
    public var size: CGFloat
    @State private var isPulsing: Bool = false
    
    public init(color: Color = .green, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(isPulsing ? 0.0 : 0.7), lineWidth: 1.2)
                .scaleEffect(isPulsing ? 2.5 : 1.0)
                .opacity(isPulsing ? 0.0 : 0.8)
                .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: isPulsing)
            
            Circle()
                .fill(color)
                .shadow(color: color.opacity(0.6), radius: 2.5, x: 0, y: 0)
        }
        .frame(width: size, height: size)
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Glowing Liquid Progress Bar

public struct LiquidProgressBar: View {
    public let value: Double
    public var height: CGFloat
    public var gradientColors: [Color]
    
    public init(
        value: Double,
        height: CGFloat = 4,
        gradientColors: [Color] = [Color.blue, Color.cyan]
    ) {
        self.value = value
        self.height = height
        self.gradientColors = gradientColors
    }
    
    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: height)
                
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(CGFloat(value) * proxy.size.width, proxy.size.width)), height: height)
                    .shadow(color: gradientColors.first?.opacity(0.5) ?? Color.clear, radius: 4, x: 0, y: 0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: height)
    }
}

#endif
