//
//  Benchmarks.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Benchmark
import P256K

// MARK: - UInt256 arithmetic benchmarks

//
// Operands are 256-bit compile-time constants; the BenchmarkPlugin's entry
// point runs each closure through package-benchmark's statistical harness.
//
// Run: swift package benchmark  (from the Projects/ directory)
//      swift package benchmark --filter "mulMod"

let benchmarks: @Sendable () -> Void = {
    // Fixed operands — both less than `mod` so modular ops need no pre-reduction.
    let lhs: UInt256 = 0xDEAD_BEEF_CAFE_F00D_DEAD_BEEF_CAFE_F00D_DEAD_BEEF_CAFE_F00D_DEAD_BEEF_CAFE_F00D
    let rhs: UInt256 = 0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF
    let mod: UInt256 = 0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFE_FFFF_FC2F

    // MARK: Addition

    Benchmark("add") { benchmark in
        var acc = lhs
        for _ in benchmark.scaledIterations {
            acc &+= rhs
        }
        blackHole(acc)
    }

    // MARK: Subtraction

    Benchmark("sub") { benchmark in
        var acc = lhs
        for _ in benchmark.scaledIterations {
            acc &-= rhs
        }
        blackHole(acc)
    }

    // MARK: Multiplication (low 256 bits)

    Benchmark("mul") { benchmark in
        var acc = lhs
        for _ in benchmark.scaledIterations {
            acc &*= rhs
        }
        blackHole(acc)
    }

    // MARK: Full-width multiplication (256×256→512)

    // Dependent chain: low half feeds next iteration's left operand.

    Benchmark("multipliedFullWidth") { benchmark in
        var acc = lhs
        var hiSink: UInt256 = .zero
        for _ in benchmark.scaledIterations {
            let (hi, lo) = acc.multipliedFullWidth(by: rhs)
            hiSink &+= hi
            acc = lo
        }
        blackHole((acc, hiSink))
    }

    // MARK: Division (via dividingFullWidth)

    // hi = r >> 128 satisfies the precondition hi < divisor on every iteration.

    Benchmark("dividingFullWidth") { benchmark in
        var hi = lhs >> 128
        for _ in benchmark.scaledIterations {
            let (_, r) = rhs.dividingFullWidth((high: hi, low: lhs))
            hi = r >> 128
        }
        blackHole(hi)
    }

    // MARK: Modular addition

    Benchmark("addMod") { benchmark in
        var acc = lhs
        for _ in benchmark.scaledIterations {
            acc = acc.addMod(rhs, modulus: mod)
        }
        blackHole(acc)
    }

    // MARK: Modular multiplication

    Benchmark("mulMod") { benchmark in
        var acc = lhs
        for _ in benchmark.scaledIterations {
            acc = acc.mulMod(rhs, modulus: mod)
        }
        blackHole(acc)
    }
}
