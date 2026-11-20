/// Where a panel is scrolled, in terms the other panel can follow.
public struct ScrollPosition: Equatable {
    /// Fractional 0-based source line at the top of the panel.
    public var line: Double
    /// Progress (0 to 1) through the panel's last viewport-height of scrolling: 0 before it, 1 at the very end.
    /// The follower blends from the line position toward its own end by this amount, so both panels reach
    /// their end together even when one is much taller than the other (see `ScrollTail`).
    public var tail: Double

    public init(line: Double, tail: Double = 0) {
        self.line = line
        self.tail = tail
    }
}

/// The end-of-document blending shared by both panels (mirrored in shared/preview/preview.js).
public enum ScrollTail {
    /// Progress through the last `viewport` of the scroll range [0, `maxOffset`].
    public static func progress(offset: Double, maxOffset: Double, viewport: Double) -> Double {
        guard maxOffset > 0 else { return 0 }
        let start = max(0, maxOffset - viewport)
        return min(1, max(0, (offset - start) / (maxOffset - start)))
    }

    /// The follower's offset: the line-matched offset, moved toward the follower's end by `tail`.
    public static func blend(lineOffset: Double, maxOffset: Double, tail: Double) -> Double {
        lineOffset + (maxOffset - lineOffset) * min(1, max(0, tail))
    }
}
