import AVFoundation

/// Tiny synth: every sound effect is rendered into a buffer once, then played through a pool of
/// player nodes feeding a hall reverb for a bit of space.
final class SoundEngine {
    enum Sound: Hashable {
        case hook, launch, combo(Int), death, newBest, tap
    }

    private static let sampleRate = 44_100.0
    private static let maxComboSound = 12

    private let engine = AVAudioEngine()
    private let bus = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()
    private let format = AVAudioFormat(standardFormatWithSampleRate: SoundEngine.sampleRate, channels: 2)!
    private var players: [AVAudioPlayerNode] = []
    private var cursor = 0
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]

    init() {
        // Ambient: respects the silent switch and mixes with whatever music is already playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])

        // Players → mixer → reverb → output. The reverb has a single input, so the players share a mixer.
        engine.attach(bus)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 22
        engine.connect(bus, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        for _ in 0..<8 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: bus, format: format)
            players.append(player)
        }

        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine,
                                               queue: .main) { [weak self] _ in self?.startIfNeeded() }

        let format = format
        DispatchQueue.global(qos: .userInitiated).async {
            var rendered: [Sound: AVAudioPCMBuffer] = [:]
            var sounds: [Sound] = [.hook, .launch, .death, .newBest, .tap]
            sounds += (2...SoundEngine.maxComboSound).map(Sound.combo)
            for sound in sounds {
                rendered[sound] = SoundEngine.buffer(SoundEngine.samples(for: sound), format: format)
            }
            DispatchQueue.main.async { self.buffers = rendered }
        }
        startIfNeeded()
    }

    func play(_ sound: Sound) {
        let key: Sound = if case let .combo(level) = sound { .combo(min(max(level, 2), SoundEngine.maxComboSound)) } else { sound }
        guard let buffer = buffers[key] else { return }
        startIfNeeded()
        guard engine.isRunning else { return }
        let player = players[cursor]
        cursor = (cursor + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    private func startIfNeeded() {
        guard !engine.isRunning else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
    }

    // MARK: Synthesis

    private enum Wave { case sine, triangle, saw }

    private static func samples(for sound: Sound) -> [Float] {
        switch sound {
        case .hook:
            let pitch = { (t: Double) in 760 + 520 * (1 - exp(-t * 38)) }
            return mix([
                tone(0.4, .sine, frequency: pitch, amplitude: envelope(0.28, attack: 0.004, decay: 0.09)),
                tone(0.4, .sine, frequency: { 2 * pitch($0) }, amplitude: envelope(0.06, attack: 0.004, decay: 0.05)),
            ])
        case .launch:
            return mix([
                noise(0.35, cutoff: { 900 + 5000 * exp(-$0 * 9) }, amplitude: envelope(0.22, attack: 0.01, decay: 0.07)),
                tone(0.25, .triangle, frequency: { 330 + min($0, 0.1) * 3300 }, amplitude: envelope(0.12, attack: 0.005, decay: 0.06)),
            ])
        case let .combo(level):
            // Climb a major pentatonic scale as the combo grows.
            let ratios: [Double] = [1, 9.0 / 8, 5.0 / 4, 3.0 / 2, 5.0 / 3]
            let step = level - 2
            let frequency = 587.33 * ratios[step % ratios.count] * pow(2, Double(min(step / ratios.count, 2)))
            return bell(frequency, duration: 0.5, volume: 0.22)
        case .death:
            return mix([
                tone(0.9, .sine, frequency: { 140 * exp(-$0 * 2.2) + 38 }, amplitude: envelope(0.45, attack: 0.005, decay: 0.35)),
                noise(0.8, cutoff: { 2400 * exp(-$0 * 3) + 200 }, amplitude: envelope(0.3, attack: 0.002, decay: 0.18)),
                tone(0.5, .saw, frequency: { 220 * exp(-$0 * 3) + 50 }, amplitude: envelope(0.08, attack: 0.005, decay: 0.15)),
            ])
        case .newBest:
            let notes = [1046.5, 1318.5, 1568.0, 2093.0]
            return mix(notes.map { bell($0, duration: 0.45, volume: 0.16) },
                       offsets: notes.indices.map { Double($0) * 0.075 })
        case .tap:
            return tone(0.06, .sine, frequency: { _ in 1800 }, amplitude: envelope(0.12, attack: 0.001, decay: 0.015))
        }
    }

    private static func bell(_ frequency: Double, duration: Double, volume: Double) -> [Float] {
        mix([
            tone(duration, .sine, frequency: { _ in frequency }, amplitude: envelope(volume, attack: 0.003, decay: 0.18)),
            tone(duration, .sine, frequency: { _ in frequency * 2.01 }, amplitude: envelope(volume * 0.3, attack: 0.003, decay: 0.08)),
            tone(duration, .sine, frequency: { _ in frequency * 3 }, amplitude: envelope(volume * 0.12, attack: 0.003, decay: 0.05)),
        ])
    }

    private static func envelope(_ peak: Double, attack: Double, decay: Double) -> (Double) -> Double {
        { t in peak * min(1, t / attack) * exp(-t / decay) }
    }

    private static func tone(_ duration: Double, _ wave: Wave, frequency: (Double) -> Double,
                             amplitude: (Double) -> Double) -> [Float] {
        let count = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            phase += 2 * .pi * frequency(t) / sampleRate
            let cycle = phase / (2 * .pi)
            let value: Double = switch wave {
            case .sine: sin(phase)
            case .triangle: 2 / .pi * asin(sin(phase))
            case .saw: 2 * (cycle - (cycle + 0.5).rounded(.down))
            }
            out[i] = Float(value * amplitude(t))
        }
        return out
    }

    private static func noise(_ duration: Double, cutoff: (Double) -> Double, amplitude: (Double) -> Double) -> [Float] {
        let count = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: count)
        var generator = SplitMix64(seed: 0xC0FFEE)
        var filtered = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let white = Double.random(in: -1...1, using: &generator)
            filtered += (1 - exp(-2 * .pi * cutoff(t) / sampleRate)) * (white - filtered)
            out[i] = Float(filtered * amplitude(t) * 2)
        }
        return out
    }

    private static func mix(_ tracks: [[Float]], offsets: [Double]? = nil) -> [Float] {
        let starts = (offsets ?? Array(repeating: 0, count: tracks.count)).map { Int($0 * sampleRate) }
        let length = zip(tracks, starts).map { $0.count + $1 }.max() ?? 0
        var out = [Float](repeating: 0, count: length)
        for (track, start) in zip(tracks, starts) {
            for (i, sample) in track.enumerated() { out[start + i] += sample }
        }
        return out
    }

    private static func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for channel in 0..<Int(format.channelCount) {
            for (i, sample) in samples.enumerated() { channels[channel][i] = tanhf(sample) }
        }
        return buffer
    }
}
