import AppKit


private enum Shape { case dot(x: Double, y: Double, d: Double), oval(x: Double, y: Double, w: Double, h: Double), ring(d: Double, w: Double),
    quill(outline: Double, stem: Double, rot: Double, dx: Double, dy: Double) }
private struct Motion { let name: String, inTime: Double, loopTime: Double, yellow: Bool, pose: (Double) -> [Shape], loop: (Double) -> [Shape]
    var outTime: Double? = nil, out: ((Double) -> [Shape])? = nil }
private struct Phase { let frames: Int, dots: [[[Double]]] }

private let base = 6.5
private func clamp(_ u: Double) -> Double { min(max(u, 0), 1) }
private func smooth(_ u: Double) -> Double { let v = clamp(u); return v * v * (3 - 2 * v) }
private func inOut(_ u: Double) -> Double { let v = clamp(u); return v < 0.5 ? 4 * v * v * v : 1 - pow(-2 * v + 2, 3) / 2 }
private func back(_ u: Double) -> Double { let v = clamp(u), c = 1.6; return 1 + (c + 1) * pow(v - 1, 3) + c * pow(v - 1, 2) }
private func osc(_ t: Double) -> Double { (1 - cos(2 * .pi * t)) / 2 }
private func lerp(_ a: Double, _ b: Double, _ u: Double) -> Double { a + (b - a) * u }
private func span(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp((t - a) / (b - a)) }

private func split(_ u: Double, y: Double = 0, x: Double = 15, side: Double = 8, mid: Double = 5.5) -> [Shape] {
    let e = back(span(u, 0.25, 1)), swell = osc(span(u, 0, 0.5) / 2)
    return [-1.0, 0, 1].map { k in .dot(x: k * x * e, y: y * smooth(u / 0.35), d: k == 0 ? lerp(base + swell, mid, e) : lerp(base, side, e)) }
}

private func sample(_ keys: [[Double]], _ f: Double, end: [Double]) -> [Double] {
    let k = keys + [end], i = min(k.lastIndex { $0[0] <= f } ?? 0, k.count - 2), a = k[i], b = k[i + 1], dt = b[0] - a[0], u = clamp((f - a[0]) / dt)
    func slope(_ j: Int, _ v: Int) -> Double { let p = k[max(j - 1, 0)], q = k[min(j + 1, k.count - 1)]; return (q[v] - p[v]) / (q[0] - p[0]) }
    let h00 = 2 * u * u * u - 3 * u * u + 1, h10 = u * u * u - 2 * u * u + u, h01 = 3 * u * u - 2 * u * u * u, h11 = u * u * u - u * u
    return (1..<a.count).map { a[$0] * h00 + slope(i, $0) * dt * h10 + b[$0] * h01 + slope(i + 1, $0) * dt * h11 }
}

private let slower = 1.05
private func tracked(_ name: String, _ phases: [Phase]) -> Motion {
    func shapes(_ p: Int, _ u: Double) -> [Shape] {
        let ph = phases[p], n = Double(ph.frames), f = u * n
        let rest = p == 0 ? clamp(1 - f / 3) : p == 2 ? clamp((f - n + 3) / 3) : 0
        return ph.dots.map { keys in
            let last = keys.last!
            let end = p == 2 ? last : phases[1].dots.map { $0[0] }.min { hypot($0[1] - last[1], $0[2] - last[2]) < hypot($1[1] - last[1], $1[2] - last[2]) }!
            let v = sample(keys, f, end: [n] + end.dropFirst()).enumerated().map { i, x in lerp(x * (i < 2 ? 0.96 : 1.05), i < 2 ? 0 : base, rest) }
            return v.count == 4 ? .oval(x: v[0], y: v[1], w: max(v[2], 0), h: max(v[3], 0)) : .dot(x: v[0], y: v[1], d: max(v[2], 0))
        }
    }
    return Motion(name: name, inTime: Double(phases[0].frames) / 30 * slower, loopTime: Double(phases[1].frames) / 30 * slower, yellow: false,
                    pose: { shapes(0, $0) }, loop: { shapes(1, $0) }, outTime: Double(phases[2].frames) / 30 * slower, out: { shapes(2, $0) })
}

private let featherIn: [[Double]] = [[0, 6.5, 0, 0], [3, 4.5, 0, 0], [3.9, 0, 0, 0], [5, 0, 0.12, 0], [7.5, 0, 0.3, 0.15], [10, 0, 0.62, 0.6], [12.5, 0, 0.9, 0.95], [15, 0, 1, 1]]
private let featherOut: [[Double]] = [[0, 0, 1, 1], [0.5, 0, 0.92, 1], [3, 0, 0.6, 0.6], [5.5, 0, 0.3, 0.15], [8, 0, 0.12, 0], [9.4, 0, 0, 0], [9.5, 4.5, 0, 0], [11, 6.5, 0, 0]]
private let featherSway: [[Double]] = [[0, 4.6, -0.5, -51], [2, 4.6, -0.8, -50], [4, 4.6, -1.5, -48], [7, 4.0, -2.1, -46], [9, 2.9, -2.0, -43], [12, 1.5, -1.6, -43],
    [14, 0.3, -1.1, -46], [17, -0.5, -0.8, -49], [19, -0.6, -0.9, -51], [22, -0.3, -1.2, -52], [24, 0.2, -1.6, -50], [27, 0.6, -1.5, -49], [29, 0.9, -1.1, -51],
    [32, 1.2, -0.8, -53], [34, 1.5, -1.1, -53], [37, 2.0, -1.4, -51], [39, 2.4, -1.4, -49], [42, 2.6, -1.2, -51], [44, 2.8, -0.9, -52], [47, 3.1, -0.9, -53],
    [49, 3.6, -1.3, -51], [52, 4.1, -1.2, -49], [54, 4.4, -0.9, -50], [57, 4.7, -0.7, -51], [59, 4.8, -0.6, -51]].map { [$0[0], $0[1] - 4.6, $0[2] + 0.5, $0[3] + 51] }
private func feather(_ track: [[Double]], _ u: Double, frames: Double) -> [Shape] {
    let v = sample(track, u * frames, end: [frames] + track.last!.dropFirst())
    return (v[0] > 0.3 ? [.dot(x: 0, y: 0, d: v[0] * 1.05)] : []) + (v[1] > 0.005 ? [.quill(outline: clamp(v[1]), stem: clamp(v[2]), rot: 0, dx: 0, dy: 0)] : [])
}

private let motions: [Motion] = [
    Motion(name: "default", inTime: 0.5, loopTime: 1.4, yellow: false, pose: { split($0) }, loop: { t in
        let p = inOut(osc(t))
        return [.dot(x: -15 + 4.5 * p, y: 0, d: 8 - 2.2 * p), .dot(x: 0, y: -1.3 * p, d: 5.5 + 2.6 * p), .dot(x: 15 - 4.5 * p, y: 0, d: 8 - 2.2 * p)]
    }),
    tracked("think", thinkKeys),
    tracked("search", searchKeys),
    tracked("read", readKeys),
    tracked("write", writeKeys),
    tracked("code", codeKeys),
    Motion(name: "compose", inTime: 16 / 30 * slower, loopTime: 62 / 30 * slower, yellow: false, pose: { feather(featherIn, $0, frames: 16) }, loop: { t in
        let v = sample(featherSway, t * 62, end: [62] + featherSway[0].dropFirst())
        return [.quill(outline: 1, stem: 1, rot: v[2], dx: v[0], dy: v[1])]
    }, outTime: 12 / 30 * slower, out: { feather(featherOut, $0, frames: 12) }),
    Motion(name: "blocked", inTime: 0.5, loopTime: 2.4, yellow: true, pose: { u in
        [.dot(x: 0, y: 0, d: lerp(base, 21, back(span(u, 0.15, 1)))), .ring(d: lerp(base, 34, back(span(u, 0, 0.85))), w: lerp(0.8, 2.3, smooth(u)))]
    }, loop: { t in [.dot(x: 0, y: 0, d: 21), .ring(d: 34 + 1.8 * inOut(osc(t)), w: 2.3)] }),
]

private func catmull(_ p: [(Double, Double)], _ n: Int = 8) -> [(Double, Double)] {
    [p[0]] + (0..<p.count - 1).flatMap { i in (1...n).map { s in
        let a = p[max(i - 1, 0)], b = p[i], c = p[i + 1], d = p[min(i + 2, p.count - 1)], t = Double(s) / Double(n)
        func h(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double { 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t) }
        return (h(a.0, b.0, c.0, d.0), h(a.1, b.1, c.1, d.1)) } }
}
private let featherOutline = catmull([(-4, 3), (-1, -5), (1, -12.5), (7.7, -16.3), (13.4, -15.4), (17.8, -9.6), (18.2, -3), (13.4, 1.0), (16.3, 4.3), (13.4, 7.7), (4.8, 9.6), (-6, 9.6)])
private let featherStem = catmull([(-12.5, 18.7), (-4.8, 7.7), (10.6, -8.6)])
private func part(_ p: [(Double, Double)], _ from: Double, _ to: Double) -> [(Double, Double)] {
    let seg = zip(p, p.dropFirst()).map { hypot($1.0 - $0.0, $1.1 - $0.1) }, total = seg.reduce(0, +)
    func at(_ s: Double) -> (Double, Double) {
        var rest = s * total
        for (i, l) in seg.enumerated() {
            if rest <= l || i == seg.count - 1 { let u = l > 0 ? min(rest / l, 1) : 0; return (lerp(p[i].0, p[i + 1].0, u), lerp(p[i].1, p[i + 1].1, u)) }
            rest -= l
        }
        return p.last!
    }
    var acc = 0.0
    let inner = zip(p.dropFirst(), seg).compactMap { pt, l -> (Double, Double)? in acc += l; return acc / total > from && acc / total < to ? pt : nil }
    return [at(from)] + inner + [at(to)]
}


final class Marks {
    let layer = CAShapeLayer()
    private struct Track { let frames: [[Shape]], paths: [CGPath] }
    private struct Segment { let name: String, loop: Bool, begin: CFTimeInterval, track: Track }
    private static var tracks: [String: (into: Track, loop: Track, out: Track)] = [:]
    private static let amber = CGColor(srgbRed: 242 / 255, green: 180 / 255, blue: 78 / 255, alpha: 1)
    private let selected: Bool
    private let delay: Double
    private var segments: [Segment] = []
    private var target: String?
    private var left: Segment?
    private var hold: Timer?

    init(selected: Bool, phase: Int) {
        self.selected = selected
        delay = Double(phase) * 0.15
        layer.actions = ["path": NSNull(), "fillColor": NSNull()]
    }

    deinit { hold?.invalidate() }

    func show(_ name: String) {
        hold?.invalidate()
        hold = nil
        guard name != target else { return }
        if target == nil || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return play(name) }
        hold = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [unowned self] _ in play(name) }
    }

    private func play(_ name: String) {
        let now = layer.convertTime(CACurrentMediaTime(), from: nil), next = Self.track(name)
        target = name
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            segments = [Segment(name: name, loop: true, begin: now, track: Track(frames: [next.loop.frames[0]], paths: [next.loop.paths[0]]))]
            return apply()
        }
        if segments.isEmpty {
            segments = [Segment(name: name, loop: false, begin: now + delay, track: next.into), Segment(name: name, loop: true, begin: now + delay + Double(next.into.frames.count) / 60, track: next.loop)]
            return apply()
        }
        let (top, frame) = self.top(at: now)
        let current = top.map { $0.track.frames[frame] } ?? [.dot(x: 0, y: 0, d: base)]
        if let top, top.loop, top.name == name {
            segments = [top]
            return apply()
        }
        let leave: Segment
        if let top, top.loop {
            left = top
            let length = Double(top.track.frames.count) / 60, end = now + length - (now - top.begin).truncatingRemainder(dividingBy: length)
            leave = end - now <= 0.35 ? Segment(name: top.name, loop: false, begin: end, track: Self.track(top.name).out) : fold(current, top.name, at: now)
            segments = [top]
        } else if let left, left.name == name, let blend = blend(current, into: left, at: now) {
            segments = [left, blend]
            return apply()
        } else {
            leave = fold(current, top?.name ?? name, at: now)
            segments = []
        }
        let grow = Segment(name: name, loop: false, begin: leave.begin + Double(leave.track.frames.count) / 60, track: next.into)
        segments += [leave, grow, Segment(name: name, loop: true, begin: grow.begin + Double(grow.track.frames.count) / 60, track: next.loop)]
        apply()
    }

    private func top(at time: CFTimeInterval) -> (Segment?, Int) {
        for segment in segments.reversed() where segment.begin <= time {
            let frame = Int((time - segment.begin) * 60), count = segment.track.frames.count
            if segment.loop { return (segment, frame % count) }
            if frame < count { return (segment, frame) }
        }
        return (nil, 0)
    }

    private func fold(_ shapes: [Shape], _ name: String, at time: CFTimeInterval) -> Segment {
        let spread = shapes.map { shape -> Double in
            switch shape {
            case let .dot(x, y, d): hypot(x, y) + abs(d - base) / 2
            case let .oval(x, y, w, h): hypot(x, y) + max(abs(w - base), abs(h - base)) / 2
            case let .ring(d, _): (d - base) / 2
            case .quill: 30
            }
        }.max() ?? 0
        let count = 6 + Int(clamp(spread / 30) * 18)
        return Segment(name: name, loop: false, begin: time, track: Self.track((1...count).map { index in
            let u = inOut(Double(index) / Double(count))
            return shapes.flatMap { shape -> [Shape] in
                switch shape {
                case let .dot(x, y, d): [.dot(x: x * (1 - u), y: y * (1 - u), d: lerp(d, base, u))]
                case let .oval(x, y, w, h): [.oval(x: x * (1 - u), y: y * (1 - u), w: lerp(w, base, u), h: lerp(h, base, u))]
                case let .ring(d, w): [.ring(d: lerp(d, base, u), w: lerp(w, 0.8, u))]
                case let .quill(outline, stem, rot, dx, dy): [.quill(outline: outline * (1 - u), stem: stem * (1 - u), rot: rot, dx: dx, dy: dy)] + (u > 0.6 ? [.dot(x: 0, y: 0, d: base * smooth((u - 0.6) / 0.4))] : [])
                }
            }
        }))
    }

    private func blend(_ shapes: [Shape], into loop: Segment, at time: CFTimeInterval) -> Segment? {
        let count = loop.track.frames.count, start = Int((time - loop.begin) * 60)
        var frames: [[Shape]] = []
        for index in 1...18 {
            let u = smooth(Double(index) / 18), to = loop.track.frames[(start + index) % count]
            guard to.count == shapes.count else { return nil }
            let mixed = zip(shapes, to).compactMap { from, to -> Shape? in
                switch (from, to) {
                case let (.dot(x, y, d), .dot(x2, y2, d2)): .dot(x: lerp(x, x2, u), y: lerp(y, y2, u), d: lerp(d, d2, u))
                case let (.oval(x, y, w, h), .oval(x2, y2, w2, h2)): .oval(x: lerp(x, x2, u), y: lerp(y, y2, u), w: lerp(w, w2, u), h: lerp(h, h2, u))
                case let (.ring(d, w), .ring(d2, w2)): .ring(d: lerp(d, d2, u), w: lerp(w, w2, u))
                case let (.quill(o, s, r, x, y), .quill(o2, s2, r2, x2, y2)): .quill(outline: lerp(o, o2, u), stem: lerp(s, s2, u), rot: lerp(r, r2, u), dx: lerp(x, x2, u), dy: lerp(y, y2, u))
                default: nil
                }
            }
            guard mixed.count == shapes.count else { return nil }
            frames.append(mixed)
        }
        return Segment(name: loop.name, loop: false, begin: time, track: Self.track(frames))
    }

    private func apply() {
        layer.removeAllAnimations()
        layer.path = segments.first?.track.paths.first ?? Self.path([.dot(x: 0, y: 0, d: base)])
        layer.fillColor = color(segments.first?.name)
        for (index, segment) in segments.enumerated() where segment.track.frames.count > 1 {
            let path = CAKeyframeAnimation(keyPath: "path"), fill = CABasicAnimation(keyPath: "fillColor"), group = CAAnimationGroup()
            path.values = segment.track.paths
            path.calculationMode = .discrete
            fill.fromValue = color(segment.name)
            fill.toValue = fill.fromValue
            group.animations = [path, fill]
            group.duration = Double(segment.track.frames.count) / 60
            path.duration = group.duration
            fill.duration = group.duration
            group.beginTime = segment.begin
            group.repeatCount = segment.loop ? .infinity : 1
            layer.add(group, forKey: "\(index)")
        }
    }

    private func color(_ name: String?) -> CGColor { selected ? .white : name == "blocked" ? Self.amber : Spark.orange.cgColor }

    private static func track(_ name: String) -> (into: Track, loop: Track, out: Track) {
        if let cached = tracks[name] { return cached }
        let motion = motions.first { $0.name == name } ?? motions[0], outTime = motion.outTime ?? motion.inTime
        func sampled(_ time: Double, _ shapes: (Double) -> [Shape]) -> Track { track((0..<max(Int(time * 60), 1)).map { shapes(Double($0) / max(time * 60, 1)) }) }
        let made = (sampled(motion.inTime) { motion.pose($0) }, sampled(motion.loopTime) { motion.loop($0) }, sampled(outTime) { motion.out?($0) ?? motion.pose(1 - $0) })
        tracks[name] = made
        return made
    }

    static func image(_ name: String, at time: CFTimeInterval) -> NSImage {
        let paths = track(name).loop.paths, ink = paths[Int(time * 60) % paths.count], color = name == "blocked" ? amber : Spark.orange.cgColor
        return NSImage(size: NSSize(width: 13, height: 13), flipped: false) { _ in
            let context = NSGraphicsContext.current!.cgContext
            context.addPath(ink)
            context.setFillColor(color)
            context.fillPath()
            return true
        }
    }

    private static func track(_ frames: [[Shape]]) -> Track { Track(frames: frames, paths: frames.map(path)) }

    private static func path(_ shapes: [Shape]) -> CGPath {
        let scale = 16.0 / 48, centre = 6.5
        func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: centre + x * scale, y: centre - y * scale) }
        func oval(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGPath { CGPath(ellipseIn: CGRect(x: centre + (x - w / 2) * scale, y: centre - (y + h / 2) * scale, width: w * scale, height: h * scale), transform: nil) }
        return shapes.reduce(CGMutablePath() as CGPath) { ink, shape in
            switch shape {
            case let .dot(x, y, d): return ink.union(oval(x, y, d, d))
            case let .oval(x, y, w, h): return ink.union(oval(x, y, w, h))
            case let .ring(d, w): return ink.union(oval(0, 0, d - w, d - w).copy(strokingWithWidth: w * scale, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
            case let .quill(outline, stem, rot, dx, dy):
                let r = rot * .pi / 180, q = 4 * Double.pi / 180
                func place(_ p: (Double, Double)) -> CGPoint {
                    let x = (p.0 - 4.6) * cos(r) - (p.1 + 0.5) * sin(r) + 4.6 + dx, y = (p.0 - 4.6) * sin(r) + (p.1 + 0.5) * cos(r) - 0.5 + dy
                    return point(0.95 * (x * cos(q) - y * sin(q)), 0.95 * (x * sin(q) + y * cos(q)))
                }
                let lines = CGMutablePath()
                lines.addLines(between: part(featherOutline, 0, outline).map(place))
                if stem > 0 { lines.addLines(between: part(featherStem, 0.35 * (1 - stem), 0.35 + 0.65 * stem).map(place)) }
                return ink.union(lines.copy(strokingWithWidth: 3.6 * scale, lineCap: .round, lineJoin: .round, miterLimit: 10))
            }
        }
    }
}


private let thinkKeys: [Phase] = [Phase(frames: 16, dots: [
        [[0, -0.2, 0.0, 3.6], [1, 2.1, -0.0, 4.4], [3, 6.8, 0.1, 7.3], [5, 10.2, 0.1, 8.7], [7, 12.9, 0.1, 9.1], [10, 15.1, 0.1, 8.7], [15, 16.5, 0.1, 8.2]],
        [[0, -0.2, 0.1, 3.6], [1, -0.0, 0.9, 2.5], [2, 0.6, 0.2, 5.0], [3, 1.9, 0.3, 5.8], [5, 3.7, 0.2, 6.1], [6, 3.7, 0.3, 6.0], [14, -0.1, 0.2, 5.5], [15, -1.2, 0.3, 5.8]],
        [[0, -0.2, 0.1, 3.6], [2, -3.8, 0.1, 4.7], [5, -11.3, 0.1, 6.2], [7, -14.7, 0.1, 7.1], [10, -16.4, 0.1, 8.0], [15, -16.0, 0.1, 8.5]]]),
    Phase(frames: 110, dots: [
        [[0, 16.7, 0.1, 8.0], [5, 16.5, 0.1, 7.5], [8, 15.0, -0.1, 7.0], [11, 12.4, -0.7, 6.3], [16, 5.7, -3.3, 5.9], [21, -3.0, -6.8, 6.0], [23, -6.7, -7.3, 6.2], [24, -8.4, -6.7, 6.3], [28, -14.0, -2.2, 6.7], [30, -16.0, -0.4, 7.1], [32, -17.0, 0.9, 7.7], [35, -15.9, 1.7, 8.6], [37, -13.1, 1.6, 9.0], [39, -8.9, 1.2, 9.5], [45, 6.4, 0.3, 9.7], [48, 11.7, 0.1, 9.1], [50, 13.9, 0.1, 8.9], [54, 16.4, 0.1, 8.2], [58, 16.9, 0.1, 8.0], [61, 16.4, 0.1, 7.5], [63, 15.5, 0.1, 7.1], [66, 13.1, 0.7, 6.5], [71, 6.0, 2.8, 5.9], [76, -3.5, 5.5, 5.9], [78, -7.5, 5.7, 6.2], [82, -14.1, 2.1, 6.7], [84, -16.2, 0.3, 7.1], [86, -17.0, -0.9, 7.8], [88, -16.2, -1.5, 8.4], [90, -13.6, -1.6, 9.0], [92, -9.4, -1.4, 9.4], [97, 3.9, -0.0, 9.7], [99, 8.1, 0.1, 9.4], [101, 11.4, 0.1, 9.2], [104, 14.4, 0.1, 8.8], [109, 16.2, 0.1, 8.2]],
        [[0, -1.8, 0.3, 5.7], [7, -7.7, -0.2, 6.1], [13, -14.6, -0.5, 6.7], [16, -16.8, 0.8, 7.6], [19, -16.4, 4.0, 8.3], [21, -14.2, 7.2, 8.6], [23, -10.5, 10.6, 8.8], [24, -8.2, 11.6, 9.0], [25, -5.7, 11.7, 9.1], [27, 0.1, 10.6, 9.2], [31, 11.1, 5.3, 9.1], [33, 14.6, 3.1, 8.8], [36, 16.6, 1.0, 7.9], [38, 16.1, 0.4, 7.3], [40, 14.7, 0.2, 6.9], [43, 11.6, 0.3, 6.1], [49, 4.5, 0.4, 5.9], [53, 1.0, 0.3, 5.8], [54, -0.8, 0.3, 5.8], [57, -2.4, 0.3, 5.7], [60, -5.1, 0.5, 5.8], [62, -7.5, 0.6, 6.5], [63, -7.5, 0.6, 7.0], [65, -10.7, 1.0, 6.3], [68, -14.2, 1.0, 6.6], [70, -16.0, 0.6, 7.1], [72, -17.0, -0.5, 7.8], [74, -16.5, -2.5, 8.2], [75, -15.5, -3.9, 8.5], [77, -11.9, -6.9, 8.9], [79, -6.7, -9.2, 9.3], [81, -0.3, -8.5, 9.4], [83, 6.4, -6.3, 9.4], [85, 11.8, -3.9, 9.1], [87, 15.1, -1.8, 8.6], [89, 16.5, -0.5, 8.0], [91, 16.2, 0.2, 7.4], [93, 14.9, 0.5, 6.9], [96, 11.7, 0.5, 6.2], [99, 7.7, 0.4, 6.8], [100, 7.6, 0.4, 6.7], [102, 4.8, 0.4, 5.9], [109, -0.5, 0.3, 5.7]],
        [[0, -15.7, 0.1, 8.6], [4, -13.0, 0.2, 9.1], [7, -8.7, 1.0, 9.6], [10, -2.5, 2.1, 9.6], [15, 9.6, 4.7, 9.3], [17, 13.4, 5.1, 8.9], [19, 15.8, 4.5, 8.4], [22, 16.6, 1.7, 7.6], [25, 14.9, -2.1, 6.8], [27, 12.6, -3.4, 6.5], [29, 9.5, -3.8, 6.2], [35, -1.3, -1.7, 5.7], [39, -8.2, -0.5, 6.2], [44, -14.4, 0.2, 6.7], [46, -15.9, 0.1, 7.1], [49, -17.0, 0.1, 7.7], [53, -16.9, 0.1, 8.2], [56, -15.7, 0.1, 8.6], [59, -13.9, -0.0, 9.0], [62, -10.2, -0.5, 9.3], [65, -4.1, -1.5, 9.7], [70, 9.0, -3.5, 9.5], [72, 13.3, -3.8, 8.9], [74, 15.9, -3.1, 8.4], [76, 16.7, -1.7, 7.7], [79, 15.1, 1.7, 7.0], [81, 12.5, 3.2, 6.4], [83, 9.2, 3.6, 6.0], [90, -4.3, 1.6, 5.6], [92, -7.8, 0.9, 6.2], [95, -12.1, 0.3, 6.3], [97, -14.3, 0.2, 6.7], [99, -15.8, 0.2, 7.0], [102, -16.9, 0.1, 7.6], [106, -17.0, 0.1, 8.1], [109, -16.2, 0.1, 8.4]]]),
    Phase(frames: 15, dots: [
        [[0, 16.1, -0.0, 8.0], [2, 15.3, -0.3, 7.7], [4, 13.2, -0.3, 6.9], [6, 9.9, 0.2, 6.2], [10, 2.4, 1.4, 7.3], [11, 1.3, 1.2, 6.8], [12, 0.1, -0.0, 6.5], [14, -0.1, 0.1, 3.5]],
        [[0, -1.0, 0.5, 5.7], [5, -4.8, 2.4, 5.3], [7, -5.0, 2.7, 6.0], [9, -3.5, 1.7, 7.2], [11, -0.7, 0.4, 8.2], [12, 0.2, 0.4, 6.6], [14, 0.2, 0.3, 2.8]],
        [[0, -15.7, -0.0, 8.3], [2, -13.6, -0.8, 8.3], [3, -11.8, -1.4, 8.1], [6, -4.8, -3.8, 7.3], [8, -1.0, -4.0, 7.3], [10, 0.4, -2.1, 7.7], [12, -0.0, 0.2, 6.8], [14, 0.1, -0.1, 3.2]]])]
private let searchKeys: [Phase] = [Phase(frames: 16, dots: [
        [[0, -0.0, 0.0, 5.3], [3, -1.5, 0.2, 5.2], [4, -2.7, 0.2, 5.0], [5, -3.7, 0.1, 5.8], [9, -11.0, 0.2, 7.6], [11, -13.9, 0.1, 8.1], [13, -15.4, 0.1, 8.3], [15, -15.9, 0.2, 8.3]],
        [[0, -0.1, 0.1, 5.5], [2, 0.4, 0.1, 5.5], [4, 1.9, 0.1, 5.9], [5, 3.0, 0.0, 6.4], [6, 5.0, 0.1, 6.2], [9, 10.8, 0.1, 7.5], [11, 13.7, 0.1, 8.1], [13, 15.2, 0.1, 8.2], [15, 15.7, 0.1, 8.3]],
        [[0, -0.1, -0.2, 5.1], [1, -0.2, -0.2, 4.8], [2, -0.4, -0.2, 5.4], [5, -2.1, 0.1, 5.5], [6, 0.0, 0.0, 5.0], [11, -0.1, 0.1, 4.1], [15, -0.1, 0.1, 4.2]]]),
    Phase(frames: 20, dots: [
        [[0, -15.8, 0.1, 8.3], [2, -14.7, 0.2, 8.3], [4, -12.4, 0.1, 8.4], [5, -10.6, 0.1, 8.4], [7, -5.7, 0.1, 8.3], [11, 6.0, 0.1, 8.4], [14, 12.3, 0.1, 8.3], [16, 14.5, 0.1, 8.4], [19, 15.6, 0.1, 8.4]],
        [[0, 15.6, 0.1, 8.3], [3, 14.6, 0.2, 8.0], [5, 13.0, 0.1, 7.8], [10, 5.8, 0.1, 6.2], [11, 4.8, 0.1, 6.1], [13, 2.4, 0.0, 4.7], [16, 0.5, 0.1, 4.1], [19, -0.0, 0.1, 4.0]],
        [[0, -0.2, 0.1, 4.2], [4, -1.9, 0.1, 4.7], [7, -4.7, 0.1, 5.3], [8, -6.8, 0.0, 5.8], [11, -11.1, 0.2, 7.2], [13, -13.3, 0.1, 7.8], [16, -15.2, 0.1, 8.2], [19, -15.8, 0.1, 8.3]]]),
    Phase(frames: 14, dots: [
        [[0, 15.4, 0.1, 8.4], [3, 13.6, 0.1, 8.1], [5, 10.8, 0.1, 7.5], [9, 3.3, 0.1, 6.0], [11, 1.0, 0.1, 5.6], [13, -0.0, 0.1, 5.5]],
        [[0, -0.0, 0.1, 4.0], [9, 0.2, 0.0, 5.0], [11, -0.5, -0.1, 5.8], [13, -0.2, -0.5, 4.6]],
        [[0, -15.7, 0.1, 8.3], [2, -14.8, 0.1, 8.1], [4, -12.7, 0.1, 7.9], [8, -5.2, 0.1, 6.4], [10, -2.3, 0.1, 5.7], [13, -0.7, 0.2, 4.8]]])]
private let readKeys: [Phase] = [Phase(frames: 21, dots: [
        [[0, 0.1, 0.0, 5.0], [2, 0.9, -0.7, 3.9], [8, 6.1, -2.9, 1.9], [13, 9.7, -3.2, 0.8], [20, 11.7, -3.2, 0.2]],
        [[0, -0.1, 0.0, 5.2], [5, 3.9, -2.2, 3.2], [11, 8.2, -4.0, 2.2], [12, -2.3, -1.5, 2.8], [16, -7.7, -4.5, 6.7], [19, -10.3, -5.9, 8.7], [20, -10.5, -6.1, 9.1]],
        [[0, -0.0, -0.1, 5.2], [6, 7.0, -4.0, 8.2], [10, 10.4, -6.2, 9.5], [15, 12.7, -7.4, 9.6], [20, 12.9, -7.4, 8.3]]]),
    Phase(frames: 60, dots: [
        [[0, 11.8, -3.2, 0.2], [1, 0.1, -2.5, 3.6], [5, 0.0, -8.0, 7.3], [10, 0.1, -12.8, 9.5], [15, -0.0, -14.9, 9.6], [19, -0.0, -14.8, 8.4], [21, -0.0, -13.6, 7.4], [24, -0.1, -9.7, 5.3], [27, 0.0, -3.8, 2.7], [29, 0.1, 0.1, 1.6], [31, -0.0, 2.9, 2.8], [34, 0.1, 7.6, 5.8], [38, 0.0, 11.9, 8.6], [41, 0.0, 13.6, 9.6], [47, -0.0, 15.1, 9.2], [50, 0.1, 14.6, 8.2], [53, 0.0, 12.1, 6.5], [55, -0.0, 8.9, 5.0], [58, -0.1, 2.0, 2.3], [59, -0.1, -0.0, 2.5]],
        [[0, -11.1, -6.4, 9.4], [6, -13.0, -7.4, 9.3], [9, -13.0, -7.5, 8.6], [11, -12.2, -7.0, 7.6], [14, -9.2, -5.3, 5.7], [19, -0.1, -0.1, 1.6], [24, 5.9, 3.4, 6.6], [28, 9.7, 5.6, 9.1], [32, 11.9, 6.9, 9.7], [37, 13.1, 7.5, 9.2], [40, 12.5, 7.2, 8.1], [42, 10.9, 6.3, 7.0], [45, 6.9, 4.0, 4.6], [49, 0.1, -0.0, 1.5], [50, -1.0, -0.7, 2.0], [55, -7.6, -4.5, 6.7], [58, -10.3, -6.0, 8.6], [59, -10.5, -6.1, 9.2]],
        [[0, 12.6, -7.2, 7.8], [3, 10.4, -6.0, 5.9], [7, 3.6, -2.2, 2.5], [9, 0.0, -0.1, 1.5], [10, -1.0, 0.5, 1.9], [14, -6.1, 3.4, 6.1], [18, -9.9, 5.6, 8.8], [23, -12.4, 7.2, 9.6], [28, -13.0, 7.5, 8.9], [31, -12.2, 7.0, 7.7], [34, -9.3, 5.3, 5.8], [39, -0.1, 0.1, 1.6], [44, 5.9, -3.3, 6.6], [49, 10.5, -6.0, 9.4], [53, 12.4, -7.1, 9.8], [59, 12.9, -7.4, 8.7]]]),
    Phase(frames: 19, dots: [
        [[0, -0.1, -0.0, 2.6], [5, 0.0, -0.0, 5.2], [18, -0.0, 0.0, 5.1]],
        [[0, -11.1, -6.4, 9.4], [6, -13.0, -7.4, 9.5], [9, -13.0, -7.5, 8.9], [11, -12.2, -7.1, 8.3], [14, -9.2, -5.3, 7.0], [16, -5.9, -3.5, 5.8], [18, -1.7, -1.1, 4.6]],
        [[0, 12.6, -7.2, 8.4], [3, 10.3, -6.0, 7.2], [5, 7.5, -4.3, 6.1], [9, 0.1, -0.1, 4.0], [10, -0.7, 0.3, 3.6], [18, -0.4, 1.2, 2.5]]])]
private let writeKeys: [Phase] = [Phase(frames: 31, dots: [
        [[0, 0.0, 0.0, 4.8, 5.2], [2, 0.6, 0.0, 3.7, 5.8], [4, 0.8, 0.7, 4.2, 5.7], [5, 0.4, 1.1, 4.9, 5.0], [6, -1.0, 2.7, 5.8, 4.2], [8, -1.4, 5.8, 6.6, 2.9], [11, -0.8, 3.6, 6.8, 0.1], [15, -0.5, 2.4, 7.0, -1.7], [16, 2.2, 5.0, 6.0, 5.1], [17, 1.9, 1.7, 8.7, 7.6], [19, 4.3, -3.3, 8.6, 8.9], [20, 5.5, -5.0, 8.4, 9.5], [21, 6.6, -6.3, 8.6, 10.0], [23, 8.9, -7.3, 8.8, 10.5], [25, 11.3, -6.3, 8.6, 10.1], [26, 12.5, -5.0, 8.6, 9.9], [27, 13.7, -3.1, 8.6, 9.6], [30, 17.2, 5.1, 8.6, 8.6]],
        [[0, -0.1, -0.7, 4.7, 5.2], [4, -0.2, 0.9, 6.2, 6.0], [6, -0.0, 3.5, 7.8, 5.8], [7, -0.0, 4.9, 8.4, 6.8], [8, -0.4, 5.2, 8.2, 7.1], [10, -2.4, -0.4, 8.4, 7.9], [12, -4.3, -4.5, 8.6, 9.3], [14, -6.3, -6.9, 8.6, 10.1], [16, -8.3, -7.3, 9.0, 10.3], [18, -10.4, -6.4, 8.7, 10.1], [20, -12.4, -4.3, 8.6, 9.8], [22, -14.4, -1.1, 8.6, 9.3], [25, -17.0, 5.1, 8.7, 8.6], [30, -17.0, 5.1, 8.6, 8.7]],
        [[0, -0.2, -0.2, 5.0, 5.3], [3, -0.2, 0.0, 5.2, 5.8], [6, 0.1, 2.8, 6.8, 6.0], [8, -0.0, 5.7, 7.6, 6.0], [9, -1.1, 3.4, 7.2, 5.8], [10, 0.0, 3.8, 7.8, 6.6], [11, 0.0, 5.3, 8.2, 6.9], [12, 0.0, 4.9, 8.6, 7.1], [13, 0.0, 2.0, 8.4, 7.6], [15, 0.0, 0.9, 8.7, 17.1], [16, -0.0, -0.9, 8.6, 18.1], [17, 0.1, -6.0, 8.6, 10.1], [19, 0.0, -7.3, 8.5, 10.1], [21, 0.2, -7.0, 8.8, 10.2], [24, 0.1, -4.1, 8.7, 9.7], [29, 0.1, 5.1, 8.6, 8.6], [30, 0.1, 5.1, 8.8, 8.5]]]),
    Phase(frames: 60, dots: [
        [[0, 17.2, 5.1, 8.5, 8.6], [9, 17.1, 5.1, 8.7, 8.6], [12, 17.1, -2.0, 8.7, 9.8], [14, 17.2, -5.9, 8.7, 10.5], [16, 17.2, -8.2, 8.7, 11.1], [19, 17.1, -9.4, 8.7, 11.7], [22, 17.1, -8.2, 8.7, 10.9], [24, 17.1, -6.0, 8.7, 9.5], [26, 17.1, -2.1, 8.6, 8.0], [29, 17.1, 6.2, 8.5, 6.0], [34, 17.1, -3.9, 8.8, 9.6], [37, 17.2, -7.2, 8.6, 11.2], [39, 17.1, -7.8, 8.7, 11.7], [41, 17.1, -7.3, 8.7, 11.4], [43, 17.1, -5.7, 8.8, 10.8], [45, 17.1, -2.8, 8.8, 10.3], [49, 17.2, 5.1, 8.8, 8.7], [59, 17.2, 5.1, 8.6, 8.6]],
        [[0, -17.0, 3.0, 8.7, 9.1], [2, -17.0, -2.0, 8.7, 9.7], [4, -17.0, -5.8, 8.6, 10.5], [6, -17.0, -8.2, 8.6, 11.2], [9, -17.0, -9.4, 8.7, 11.4], [12, -17.0, -8.3, 8.7, 10.7], [14, -17.0, -6.0, 8.8, 9.6], [16, -17.0, -2.1, 8.7, 8.0], [19, -17.0, 6.3, 8.7, 6.0], [24, -17.0, -3.9, 8.7, 9.6], [27, -17.0, -7.2, 8.6, 11.3], [29, -16.9, -7.7, 8.8, 11.5], [31, -16.9, -7.3, 8.8, 11.2], [34, -17.0, -4.5, 8.7, 10.6], [39, -17.0, 5.1, 8.5, 8.6], [59, -17.0, 5.1, 8.6, 8.7]],
        [[0, 0.1, 5.1, 8.8, 8.6], [4, 0.1, 5.1, 8.8, 8.7], [7, 0.1, -2.1, 8.8, 9.7], [9, 0.1, -5.9, 8.6, 10.5], [11, 0.1, -8.2, 8.6, 11.2], [13, 0.1, -9.3, 8.6, 11.6], [16, 0.0, -8.8, 8.7, 11.2], [19, 0.1, -6.0, 8.7, 9.5], [21, -0.0, -2.2, 8.5, 8.2], [24, 0.1, 6.2, 8.4, 6.2], [27, 0.1, -0.3, 8.4, 8.3], [29, 0.1, -3.9, 8.8, 9.7], [32, 0.1, -7.2, 8.8, 11.2], [34, 0.1, -7.7, 8.7, 11.6], [36, 0.1, -7.3, 8.6, 11.4], [39, 0.1, -4.4, 8.7, 10.7], [44, 0.2, 5.2, 8.6, 8.6], [59, 0.1, 5.1, 8.8, 8.5]]]),
    Phase(frames: 14, dots: [
        [[0, 17.1, 5.1, 8.6, 8.6], [3, 17.2, 5.1, 8.5, 8.6], [5, 16.3, 4.9, 8.6, 8.6], [6, 14.6, 4.3, 8.3, 8.3], [7, 10.8, 3.1, 7.5, 8.0], [8, 5.8, 1.2, 6.1, 7.6], [9, 2.8, 0.3, 5.6, 7.0], [10, 1.1, -0.4, 5.4, 5.5], [12, 0.1, -1.4, 3.8, 2.5], [13, -0.1, -1.8, 3.1, 1.6]],
        [[0, -16.8, 5.0, 8.6, 8.7], [1, -16.2, 4.8, 8.5, 8.6], [2, -14.5, 4.2, 8.4, 8.4], [3, -10.8, 3.0, 8.1, 8.2], [4, -5.8, 1.2, 7.6, 7.5], [5, -2.9, 0.8, 6.5, 6.2], [6, -1.4, 0.5, 5.7, 5.5], [7, -1.0, 0.3, 4.8, 5.1], [8, 0.2, 0.4, 6.2, 5.8], [9, 1.2, 0.4, 7.2, 5.5], [11, 0.7, 0.2, 4.9, 5.2], [13, 0.3, 0.0, 4.5, 5.0]],
        [[0, 0.1, 5.1, 8.8, 8.6], [4, 0.1, 4.3, 8.2, 8.4], [6, 0.1, 1.4, 6.5, 7.6], [8, 0.2, -0.1, 5.0, 5.9], [10, -0.1, -0.0, 4.8, 4.8], [13, -0.4, -0.1, 4.2, 4.7]]])]
private let codeKeys: [Phase] = [Phase(frames: 16, dots: [
        [[0, 0.1, -0.2, 5.8], [2, 0.2, -0.3, 6.2], [3, 0.2, -0.4, 7.0], [4, 0.5, -0.7, 7.7], [5, 1.6, -1.8, 7.3], [6, 3.7, -4.1, 7.1], [7, 6.6, -7.3, 7.8], [8, 8.7, -9.7, 8.4], [9, 9.8, -10.9, 8.7], [11, 10.9, -12.1, 9.0], [15, 11.3, -12.4, 9.1]],
        [[0, 0.4, 0.5, 5.3], [2, 0.6, 0.7, 5.3], [4, 0.8, 1.0, 6.9], [5, 2.0, 1.9, 6.9], [6, 3.9, 3.8, 7.2], [7, 7.1, 6.9, 7.9], [8, 9.3, 9.1, 8.4], [9, 10.4, 10.2, 8.7], [11, 11.7, 11.2, 9.2], [15, 11.9, 11.7, 9.2]],
        [[0, -0.7, 0.2, 5.0], [3, -0.9, 0.5, 5.8], [5, -2.0, 2.1, 6.8], [6, -3.6, 4.1, 7.3], [7, -6.6, 7.4, 7.9], [8, -8.6, 9.7, 8.4], [9, -9.7, 10.9, 8.7], [12, -11.1, 12.4, 9.0], [15, -11.1, 12.6, 9.2]],
        [[0, -0.2, -0.5, 5.5], [3, -0.8, -1.0, 5.2], [5, -1.9, -1.8, 7.0], [6, -3.8, -3.6, 7.3], [7, -6.8, -6.6, 7.7], [8, -9.0, -8.7, 8.1], [9, -10.1, -9.8, 8.4], [12, -11.4, -11.1, 8.9], [15, -11.5, -11.3, 9.0]]]),
    Phase(frames: 75, dots: [
        [[0, 11.6, -12.2, 9.1], [17, 12.0, -11.8, 9.2], [19, 11.9, -11.2, 9.2], [21, 11.5, -9.9, 9.3], [23, 10.6, -6.8, 9.5], [24, 9.5, -4.1, 9.6], [26, 6.3, 3.4, 9.7], [28, 1.0, 11.3, 9.6], [29, -1.9, 13.9, 9.4], [30, -4.3, 15.1, 9.3], [31, -6.4, 15.2, 9.2], [34, -10.0, 13.6, 9.1], [38, -11.5, 12.2, 9.1], [53, -11.8, 11.7, 8.9], [56, -11.4, 11.2, 8.9], [58, -10.9, 9.9, 8.9], [60, -9.8, 7.3, 8.8], [61, -9.0, 5.1, 8.7], [63, -6.4, -1.0, 8.6], [65, -2.1, -8.6, 8.6], [66, 0.5, -11.8, 8.7], [67, 3.1, -13.7, 8.8], [68, 5.3, -14.4, 8.8], [70, 8.6, -14.1, 8.9], [74, 12.0, -11.8, 9.1]],
        [[0, 11.9, 11.4, 9.2], [3, 11.3, 9.1, 9.3], [5, 9.9, 5.0, 9.6], [6, 8.5, 1.8, 9.6], [7, 6.8, -2.2, 9.5], [9, 1.7, -10.5, 9.4], [10, -1.1, -13.3, 9.6], [11, -3.7, -14.8, 9.6], [12, -5.9, -15.1, 9.2], [15, -9.8, -13.5, 9.1], [19, -11.4, -12.2, 9.0], [34, -11.7, -11.7, 9.0], [37, -11.4, -11.2, 8.8], [39, -11.0, -10.0, 8.7], [41, -10.1, -7.6, 8.6], [42, -9.3, -5.7, 8.6], [44, -6.8, 0.3, 8.4], [47, -0.2, 11.2, 8.6], [48, 2.5, 13.4, 8.7], [49, 4.8, 14.4, 8.7], [50, 6.8, 14.6, 8.9], [52, 9.5, 13.8, 8.9], [55, 11.3, 12.6, 9.0], [62, 11.9, 11.9, 8.9], [74, 11.9, 12.0, 9.1]],
        [[0, -11.3, 12.4, 9.2], [15, -11.8, 11.8, 9.0], [20, -11.1, 10.2, 8.9], [22, -10.2, 8.0, 8.8], [23, -9.5, 6.2, 8.7], [24, -8.6, 3.9, 8.6], [25, -7.3, 0.7, 8.6], [26, -5.5, -3.0, 8.6], [28, -0.8, -10.3, 8.6], [29, 1.7, -12.8, 8.7], [30, 4.2, -14.2, 8.8], [31, 6.3, -14.6, 9.0], [34, 10.0, -13.3, 9.1], [38, 11.7, -12.2, 9.2], [54, 12.0, -11.8, 9.2], [57, 11.8, -11.1, 9.4], [59, 11.3, -9.4, 9.5], [61, 10.1, -5.5, 9.5], [62, 8.9, -2.6, 9.6], [63, 7.2, 1.3, 9.6], [65, 2.5, 9.7, 9.6], [66, -0.3, 12.9, 9.5], [67, -3.0, 14.6, 9.3], [68, -5.4, 15.2, 9.2], [70, -8.7, 14.5, 9.2], [74, -11.8, 12.0, 9.1]],
        [[0, -11.4, -10.9, 9.0], [3, -10.3, -8.3, 8.8], [4, -9.7, -6.7, 8.7], [6, -7.6, -1.5, 8.6], [8, -3.9, 6.0, 8.6], [10, 1.2, 12.4, 8.7], [11, 3.7, 14.1, 8.9], [12, 5.8, 14.6, 8.9], [15, 9.9, 13.6, 9.1], [18, 11.5, 12.5, 9.2], [23, 12.0, 12.0, 9.2], [35, 12.0, 11.9, 9.0], [39, 11.7, 10.6, 9.3], [41, 11.0, 8.3, 9.5], [42, 10.3, 6.3, 9.5], [44, 7.7, -0.2, 9.5], [46, 3.2, -8.6, 9.7], [47, 0.4, -12.0, 9.5], [48, -2.4, -14.2, 9.3], [49, -4.9, -15.1, 9.2], [50, -6.8, -15.0, 9.1], [52, -9.3, -13.9, 9.0], [55, -11.1, -12.5, 9.0], [61, -11.8, -11.8, 9.2], [74, -11.8, -11.9, 9.1]]]),
    Phase(frames: 9, dots: [
        [[0, 11.8, -11.7, 9.1], [2, 10.2, -10.1, 8.6], [3, 7.5, -7.5, 8.0], [4, 3.5, -3.4, 6.9], [5, 1.4, 1.4, 6.5], [6, 0.1, 1.9, 3.9], [8, -1.9, 2.4, 0.2]],
        [[0, 11.8, 11.8, 9.0], [2, 10.3, 10.2, 8.6], [3, 7.6, 7.5, 8.0], [4, 3.5, 3.5, 7.0], [5, 1.4, -1.4, 6.7], [6, 0.0, -2.1, 3.5], [8, -1.8, -3.1, -1.0]],
        [[0, -11.6, 11.8, 9.1], [2, -10.1, 10.2, 8.7], [3, -7.4, 7.5, 8.0], [4, -3.4, 3.5, 7.1], [5, -1.5, 1.4, 6.5], [7, 0.0, -0.0, 6.5], [8, -0.0, -0.1, 6.1]],
        [[0, -11.7, -11.7, 9.1], [2, -10.1, -10.1, 8.7], [3, -7.5, -7.4, 8.1], [4, -3.4, -3.3, 7.1], [5, -1.3, -1.1, 7.1], [6, 0.1, 0.0, 7.5], [7, 0.2, 0.1, 6.3], [8, 0.3, 0.1, 6.0]]])]
