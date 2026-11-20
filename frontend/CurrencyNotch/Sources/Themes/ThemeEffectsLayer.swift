import AppKit
import CurrencyCore
import SwiftUI

/// Particles and shimmer for a theme (SPEC F25–F26), clipped to the surface shape with a layer mask.
/// - Particles: `ParticleSimulation` (core) stepped by a display link capped at 12 fps, moving a few sprite
///   layers (ADR-0020). `CAEmitterLayer` forced full-refresh compositing (+≈30 % WindowServer CPU).
/// - Shimmer / flicker: Core Animation, with a 12 fps frame-rate cap.
/// Pausing stops spawning (live particles finish, then the display link stops) and freezes the shimmer.
struct ThemeEffectsLayer: NSViewRepresentable {
    let spec: ThemeSpec
    let background: ThemeBackground
    let cornerRadius: CGFloat
    let running: Bool

    func makeNSView(context: Context) -> ThemeEffectsView { ThemeEffectsView() }

    func updateNSView(_ view: ThemeEffectsView, context: Context) {
        view.configure(spec: spec, background: background, cornerRadius: cornerRadius)
        view.setRunning(running)
    }
}

final class ThemeEffectsView: NSView {
    private static let effectsFrameRate = CAFrameRateRange(minimum: 8, maximum: 12, preferred: 12)

    private var spec: ThemeSpec?
    private var background: ThemeBackground?
    private var cornerRadius: CGFloat = 0
    private var running = false
    private let effectsLayer = CALayer()
    private let particleLayer = CALayer()
    private let mask = CAShapeLayer()

    private var simulation: ParticleSimulation?
    private var sprites: [CALayer] = []
    private var displayLinkHandle: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(effectsLayer)
        layer?.addSublayer(particleLayer)
        layer?.mask = mask
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    // Purely decorative: never take mouse events from the pill.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(spec: ThemeSpec, background: ThemeBackground, cornerRadius: CGFloat) {
        guard spec != self.spec || background != self.background || cornerRadius != self.cornerRadius else { return }
        self.spec = spec
        self.background = background
        self.cornerRadius = cornerRadius
        needsLayout = true
    }

    func setRunning(_ running: Bool) {
        guard running != self.running else { return }
        self.running = running
        applyRunning()
    }

    override func layout() {
        super.layout()
        rebuild()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rebuild()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            displayLinkHandle?.invalidate()
            displayLinkHandle = nil
        } else {
            applyRunning()
        }
    }

    // MARK: - Build

    private func rebuild() {
        guard let spec, bounds.width > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let radius = min(cornerRadius, bounds.height / 2)
        mask.frame = bounds
        mask.path = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
        effectsLayer.frame = bounds
        effectsLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        particleLayer.frame = bounds
        #if DEBUG
        // Measurement switch: CURRENCY_NOTCH_EFFECTS=particles|shimmer keeps only that part.
        let only = ProcessInfo.processInfo.environment["CURRENCY_NOTCH_EFFECTS"]
        configureParticles(only == "shimmer" ? nil : spec.particles)
        if only != "particles" { for effect in spec.effects { addEffect(effect) } }
        #else
        configureParticles(spec.particles)
        for effect in spec.effects { addEffect(effect) }
        #endif
        CATransaction.commit()
        applyRunning()
    }

    // MARK: - Particles

    private func configureParticles(_ particles: ParticleSpec?) {
        sprites.forEach { $0.removeFromSuperlayer() }
        sprites = []
        guard let particles else {
            simulation = nil
            return
        }
        if simulation?.spec == particles {
            simulation?.resize(bounds.size)
        } else {
            simulation = ParticleSimulation(spec: particles, size: bounds.size, seed: UInt64(bounds.width * 7 + bounds.height))
        }
        let scale = window?.backingScaleFactor ?? 2
        let images = particles.colors.map { ParticleImages.image(for: particles.kind, color: $0, glow: particles.glow, scale: scale) }
        sprites = (0..<ParticleSimulation.maxParticles).map { _ in
            let sprite = CALayer()
            sprite.isHidden = true
            sprite.contentsScale = scale
            sprite.contentsGravity = .resizeAspect
            sprite.actions = ["position": NSNull(), "bounds": NSNull(), "opacity": NSNull(), "transform": NSNull(),
                              "hidden": NSNull(), "contents": NSNull()]
            particleLayer.addSublayer(sprite)
            return sprite
        }
        spriteImages = images
        syncSprites()
    }

    private var spriteImages: [CGImage?] = []

    @objc private func tick(_ link: CADisplayLink) {
        guard var sim = simulation else { return }
        let now = link.timestamp
        let dt = lastTimestamp.map { now - $0 } ?? (1.0 / Double(ParticleSimulation.preferredFramesPerSecond))
        lastTimestamp = now
        sim.isEmitting = running
        sim.step(dt)
        simulation = sim
        syncSprites()
        if sim.isIdle { link.isPaused = true; lastTimestamp = nil }
    }

    private func syncSprites() {
        guard let sim = simulation else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, sprite) in sprites.enumerated() {
            guard index < sim.particles.count else {
                sprite.isHidden = true
                continue
            }
            let p = sim.particles[index]
            // Glow sprites draw larger than the particle; the image is sized for that.
            let side = p.size * ParticleImages.glowScale
            sprite.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            sprite.position = CGPoint(x: p.x, y: p.y)
            sprite.transform = CATransform3DMakeRotation(p.angle, 0, 0, 1)
            sprite.opacity = Float(p.opacity)
            sprite.contents = spriteImages.indices.contains(p.colorIndex) ? spriteImages[p.colorIndex] : nil
            sprite.isHidden = false
        }
        CATransaction.commit()
    }

    private func ensureDisplayLink() -> CADisplayLink? {
        if displayLinkHandle == nil, window != nil {
            let link = displayLink(target: self, selector: #selector(tick(_:)))
            let fps = Float(ParticleSimulation.preferredFramesPerSecond)
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: fps, preferred: fps)
            link.add(to: .main, forMode: .common)
            displayLinkHandle = link
        }
        return displayLinkHandle
    }

    // MARK: - Shimmer and flicker

    private func addEffect(_ effect: ThemeEffect) {
        switch effect {
        case .rimShimmer(let period):
            let sweep = shimmerBand(period: period, sweepFraction: 0.3)
            // Only the rim shows the sweep.
            let rimMask = CAShapeLayer()
            rimMask.frame = bounds
            rimMask.path = mask.path
            rimMask.fillColor = nil
            rimMask.strokeColor = NSColor.white.cgColor
            rimMask.lineWidth = 3
            sweep.mask = rimMask
            effectsLayer.addSublayer(sweep)
        case .stripeShimmer(let period):
            guard case .stripes(_, _, let fraction, _) = background else { return }
            let sweep = shimmerBand(period: period, sweepFraction: 0.6, opacity: 0.45)
            let stripeMask = CAShapeLayer()
            stripeMask.frame = bounds
            let path = CGMutablePath()
            // Stripe geometry is defined top-down; layer coordinates are bottom-up.
            for band in StripeGeometry.bands(height: bounds.height, fraction: fraction) {
                path.addRect(CGRect(x: 0, y: bounds.height - band.minY - band.height, width: bounds.width, height: band.height))
            }
            stripeMask.path = path
            sweep.mask = stripeMask
            effectsLayer.addSublayer(sweep)
        case .emberFlicker(let amount, let minInterval, let maxInterval):
            let flicker = CALayer()
            flicker.frame = bounds
            flicker.backgroundColor = NSColor.black.cgColor
            flicker.opacity = 0
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            var generator = SplitMix64(seed: 0xF1CE)   // deterministic "irregular" timing
            var times: [Double] = [0]
            var values: [Float] = [0]
            while times.last! < 4 {
                times.append(times.last! + generator.next(in: minInterval...maxInterval))
                values.append(Float(generator.next(in: 0...(amount * 2))))
            }
            let total = times.last!
            animation.keyTimes = times.map { NSNumber(value: $0 / total) }
            animation.values = values
            animation.duration = total
            animation.repeatCount = .infinity
            animation.calculationMode = .linear
            animation.preferredFrameRateRange = Self.effectsFrameRate
            flicker.add(animation, forKey: "flicker")
            effectsLayer.addSublayer(flicker)
        }
    }

    /// A soft white highlight that sweeps left → right once per `period`.
    private func shimmerBand(period: Double, sweepFraction: Double, opacity: Float = 0.8) -> CAGradientLayer {
        let band = CAGradientLayer()
        let width = max(bounds.width * 0.35, 24)
        band.frame = CGRect(x: -width, y: 0, width: width, height: bounds.height)
        band.startPoint = CGPoint(x: 0, y: 0.5)
        band.endPoint = CGPoint(x: 1, y: 0.5)
        band.colors = [NSColor.white.withAlphaComponent(0).cgColor, NSColor.white.withAlphaComponent(CGFloat(opacity)).cgColor,
                       NSColor.white.withAlphaComponent(0).cgColor]
        let move = CAKeyframeAnimation(keyPath: "position.x")
        move.values = [-width / 2, bounds.width + width / 2, bounds.width + width / 2]
        move.keyTimes = [0, NSNumber(value: sweepFraction), 1]
        move.duration = period
        move.repeatCount = .infinity
        move.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .linear)]
        move.preferredFrameRateRange = Self.effectsFrameRate
        band.add(move, forKey: "sweep")
        return band
    }

    // MARK: - Pause / resume

    private func applyRunning() {
        if running, simulation != nil, let link = ensureDisplayLink() {
            link.isPaused = false
        }
        // When stopping, the display link keeps ticking until live particles finish, then pauses itself.
        // Freeze or resume the shimmer/flicker timelines without rebuilding them.
        if running, effectsLayer.speed == 0 {
            let pausedAt = effectsLayer.timeOffset
            effectsLayer.speed = 1
            effectsLayer.timeOffset = 0
            effectsLayer.beginTime = 0
            effectsLayer.beginTime = effectsLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
        } else if !running, effectsLayer.speed != 0 {
            let now = effectsLayer.convertTime(CACurrentMediaTime(), from: nil)
            effectsLayer.speed = 0
            effectsLayer.timeOffset = now
        }
    }
}

/// Small particle images drawn in code, one per color (no image assets, no third-party art).
@MainActor
enum ParticleImages {
    /// Sprites are drawn this much larger than the particle size to leave room for a glow.
    static let glowScale: Double = 1.8
    private static var cache: [String: CGImage] = [:]

    static func image(for kind: ParticleKind, color: RGBA, glow: RGBA?, scale: CGFloat) -> CGImage? {
        let key = "\(kind.rawValue)-\(color)-\(String(describing: glow))@\(scale)"
        if let cached = cache[key] { return cached }
        let pixels = Int(12 * scale)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let full = CGRect(x: 0, y: 0, width: pixels, height: pixels)
        let center = CGPoint(x: full.midX, y: full.midY)
        // The particle itself occupies the middle 1/glowScale of the image.
        let radius = Double(pixels) / 2 / glowScale
        let cg = NSColor(Color(color)).cgColor
        if let glow {
            context.setShadow(offset: .zero, blur: CGFloat(radius * 0.9), color: NSColor(Color(glow)).cgColor)
        }
        context.setFillColor(cg)
        context.setStrokeColor(cg)
        switch kind {
        case .snow:
            // Six-armed flake.
            context.setLineWidth(max(1, scale * 0.7))
            context.setLineCap(.round)
            for i in 0..<6 {
                let angle = Double(i) * .pi / 3
                context.move(to: center)
                context.addLine(to: CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
            }
            context.strokePath()
        case .sparks:
            // Soft round glow.
            let colors = [cg, cg.copy(alpha: 0) ?? cg] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                                           endRadius: radius, options: [])
            }
        case .sparkles:
            // Four-point star.
            let inner = radius * 0.28
            let path = CGMutablePath()
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4 - .pi / 2
                let r = i.isMultiple(of: 2) ? radius : inner
                let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                i == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
        let image = context.makeImage()
        cache[key] = image
        return image
    }
}
