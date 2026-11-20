import CoreGraphics
import Foundation

/// One particle. Coordinates in points, origin bottom-left (AppKit layer space).
public struct ParticleState: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var size: Double
    public var angle: Double
    public var spinRate: Double
    public var age: Double
    public var lifetime: Double
    public var opacity: Double
    public var colorIndex: Int
}

/// A small particle system stepped at a capped frame rate (ADR-0020). `CAEmitterLayer` makes the window server
/// recomposite at the display's full refresh rate (+≈30 % WindowServer CPU measured); stepping 12 times a
/// second keeps the look of slow snow/sparks at roughly a fifth of the cost.
public struct ParticleSimulation: Sendable {
    public static let preferredFramesPerSecond = 12
    public static let maxParticles = 40
    /// How far outside the bounds a particle may travel before it's removed.
    public static let margin: Double = 6
    /// Longest step simulated at once (e.g. after sleep), so a gap doesn't burst-spawn.
    public static let maxStep: Double = 0.25

    public let spec: ParticleSpec
    public private(set) var size: CGSize
    public private(set) var particles: [ParticleState] = []
    public private(set) var spawnedCount = 0
    public var isEmitting = true

    private var spawnDebt = 0.0
    private var random: SplitMix64

    public init(spec: ParticleSpec, size: CGSize, seed: UInt64) {
        self.spec = spec
        self.size = size
        random = SplitMix64(seed: seed)
    }

    /// Nothing alive and nothing being emitted: the display link can stop.
    public var isIdle: Bool { !isEmitting && particles.isEmpty }

    public mutating func resize(_ newSize: CGSize) {
        size = newSize
    }

    public mutating func step(_ rawDelta: TimeInterval) {
        let dt = min(max(rawDelta, 0), Self.maxStep)
        let width = Double(size.width), height = Double(size.height), margin = Self.margin
        particles = particles.compactMap { particle in
            var p = particle
            p.age += dt
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.angle += p.spinRate * dt
            p.opacity = spec.fadesOut ? max(0, 1 - p.age / p.lifetime) : 1
            let outside = p.x < -margin || p.x > width + margin || p.y < -margin || p.y > height + margin
            return p.age >= p.lifetime || outside ? nil : p
        }
        guard isEmitting else { spawnDebt = 0; return }
        spawnDebt += spec.birthRate * dt
        while spawnDebt >= 1 {
            spawnDebt -= 1
            guard particles.count < Self.maxParticles else { continue }
            particles.append(spawn(width: width, height: height))
            spawnedCount += 1
        }
    }

    private mutating func spawn(width: Double, height: Double) -> ParticleState {
        let speed = random.next(in: spec.speed)
        let size = random.next(in: spec.size)
        let lifetime = spec.lifetime * random.next(in: 0.8...1.2)
        var x = random.next(in: 0...max(width, 1))
        var y: Double
        var vx: Double
        var vy: Double
        switch spec.direction {
        case .down:
            y = height + size / 2
            vy = -speed
            vx = random.next(in: -0.25...0.25) * speed
        case .up:
            y = -size / 2
            vy = speed
            vx = random.next(in: -0.2...0.2) * speed
        case .drift:
            y = random.next(in: 0...max(height, 1))
            let direction = random.next(in: 0...(2 * Double.pi))
            vx = cos(direction) * speed
            vy = sin(direction) * speed
            x = min(max(x, 0), width)
        }
        return ParticleState(x: x, y: y, vx: vx, vy: vy, size: size, angle: random.next(in: 0...(2 * Double.pi)),
                             spinRate: spec.spin * random.next(in: -1...1), age: 0, lifetime: lifetime,
                             opacity: 1, colorIndex: Int(random.next() % UInt64(max(spec.colors.count, 1))))
    }
}

/// Small deterministic random generator (repeatable particles and flicker timing).
public struct SplitMix64: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + Double(next() >> 11) / Double(1 << 53) * (range.upperBound - range.lowerBound)
    }
}
