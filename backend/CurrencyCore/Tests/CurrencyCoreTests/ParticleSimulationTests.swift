import Foundation
import Testing
@testable import CurrencyCore

@Suite("ParticleSimulation")
struct ParticleSimulationTests {
    let size = CGSize(width: 200, height: 34)
    let frame = 1.0 / 24

    func spec(_ id: ThemeID) -> ParticleSpec { ThemeRegistry.spec(id, appearance: .dark).particles! }

    func run(_ sim: inout ParticleSimulation, seconds: Double) {
        for _ in 0..<Int(seconds / frame) { sim.step(frame) }
    }

    @Test(arguments: [ThemeID.ice, .fire, .israel])
    func spawnRateMatchesBirthRate(_ id: ThemeID) {
        var sim = ParticleSimulation(spec: spec(id), size: size, seed: 1)
        run(&sim, seconds: 10)
        let expected = spec(id).birthRate * 10
        #expect(abs(Double(sim.spawnedCount) - expected) <= expected * 0.1 + 1)
    }

    @Test func liveCountStaysBoundedAndCapped() {
        var sim = ParticleSimulation(spec: spec(.ice), size: size, seed: 2)
        run(&sim, seconds: 30)
        // Snow at 6/s falls 34 pt at 8–14 pt/s: only a handful are alive at once.
        #expect(sim.particles.count > 0)
        #expect(sim.particles.count <= ParticleSimulation.maxParticles)
    }

    @Test func snowFallsDownAndSparksRise() {
        var snow = ParticleSimulation(spec: spec(.ice), size: size, seed: 3)
        run(&snow, seconds: 2)
        #expect(snow.particles.allSatisfy { $0.vy < 0 })
        var sparks = ParticleSimulation(spec: spec(.fire), size: size, seed: 3)
        run(&sparks, seconds: 2)
        #expect(sparks.particles.allSatisfy { $0.vy > 0 })
    }

    @Test func particlesStayNearBoundsAndDieOutside() {
        var sim = ParticleSimulation(spec: spec(.ice), size: size, seed: 4)
        run(&sim, seconds: 20)
        let margin = ParticleSimulation.margin
        for p in sim.particles {
            #expect(p.x >= -margin && p.x <= size.width + margin)
            #expect(p.y >= -margin && p.y <= size.height + margin)
        }
    }

    @Test func fadingParticlesLoseOpacityWithAge() {
        var sim = ParticleSimulation(spec: spec(.fire), size: size, seed: 5)
        run(&sim, seconds: 3)
        for p in sim.particles {
            #expect(abs(p.opacity - max(0, 1 - p.age / p.lifetime)) < 1e-9)
        }
    }

    @Test func israelSparklesDriftInsideThePill() {
        var sim = ParticleSimulation(spec: spec(.israel), size: size, seed: 6)
        run(&sim, seconds: 5)
        #expect(!sim.particles.isEmpty)
        #expect(Set(sim.particles.map(\.colorIndex)).isSubset(of: [0, 1]))
    }

    @Test func stoppingEmissionDrainsToIdle() {
        var sim = ParticleSimulation(spec: spec(.fire), size: size, seed: 7)
        run(&sim, seconds: 3)
        #expect(!sim.isIdle)
        sim.isEmitting = false
        let spawnedBefore = sim.spawnedCount
        run(&sim, seconds: spec(.fire).lifetime * 1.5 + 1)
        #expect(sim.spawnedCount == spawnedBefore)
        #expect(sim.isIdle)
    }

    @Test func sameSeedIsDeterministic() {
        var a = ParticleSimulation(spec: spec(.ice), size: size, seed: 42)
        var b = ParticleSimulation(spec: spec(.ice), size: size, seed: 42)
        run(&a, seconds: 4)
        run(&b, seconds: 4)
        #expect(a.particles == b.particles)
    }

    @Test func longFrameGapsAreClamped() {
        var sim = ParticleSimulation(spec: spec(.ice), size: size, seed: 8)
        sim.step(30)   // e.g. after sleep
        #expect(sim.spawnedCount <= Int(spec(.ice).birthRate * ParticleSimulation.maxStep) + 1)
    }

    @Test func frameRateCapIsLow() {
        #expect(ParticleSimulation.preferredFramesPerSecond <= 30)
    }
}
