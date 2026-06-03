#!/usr/bin/env swift
//
// Luma app-icon generator.
//
// Renders Luma's icon — a cool→warm colour-temperature track with a tactile knob,
// the literal control the app performs on your display — natively at each macOS
// icon size with SwiftUI's ImageRenderer, and writes the ten PNGs into the
// `AppIcon.appiconset` asset catalog. A 1024px master is also written to
// `docs/luma-icon-1024.png` for preview/README use.
//
// Run from the repo root:  swift script/generate_icon.swift [appiconset-dir]
// (package_release.sh invokes it with no arguments before xcodegen + xcodebuild.)
//
// Built the same way as Boswell's icon (SwiftUI → ImageRenderer → native per-size),
// adapted to Luma's asset-catalog pipeline rather than a hand-packed .icns. The tile
// shares the family DNA used across these apps: the 824px Big Sur squircle on the
// 1024 grid, a warm-paper gradient, a baked floating shadow, and a hairline border.

import AppKit
import Foundation
import SwiftUI

extension Color {
    init(hex: UInt32, _ opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

// MARK: - Palette

private enum P {
    // family tile (shared with the Boswell / Redline icons)
    static let paperTop = Color(hex: 0xFDFBF6)
    static let paperBot = Color(hex: 0xEFE9DB)
    static let border   = Color(hex: 0xE4DECF)
    static let shadow   = Color(hex: 0x281E12)
    static let inkSoft  = Color(hex: 0xB3AD9F)
    // colour-temperature track (cool daylight → warm night)
    static let coolEdge = Color(hex: 0xBFD4ED)
    static let coolMid  = Color(hex: 0xDDE7E6)
    static let warmMid  = Color(hex: 0xF3D08A)
    static let amber    = Color(hex: 0xF0A23E)
    static let amberDeep = Color(hex: 0xDD7327)
    static let ember    = Color(hex: 0xC8551A)
    // knob material
    static let knobTop  = Color(hex: 0xF4F1E9)
    static let knobBot  = Color(hex: 0xD7D2C6)
    static let knobWall = Color(hex: 0xBBB6AA)
    static let knobDeep = Color(hex: 0xA7A296)
}

private func vGrad(_ c: [Color]) -> LinearGradient {
    LinearGradient(colors: c, startPoint: .top, endPoint: .bottom)
}

// MARK: - Family tile

private struct FamilyTile<Content: View>: View {
    @ViewBuilder var content: Content
    private let tile = RoundedRectangle(cornerRadius: 185, style: .continuous)
    var body: some View {
        ZStack {
            tile
                .fill(vGrad([P.paperTop, P.paperBot])
                    .shadow(.inner(color: .white.opacity(0.6), radius: 2, y: 2)))
                .frame(width: 824, height: 824)
                .overlay(tile.strokeBorder(P.border, lineWidth: 2))
                .shadow(color: P.shadow.opacity(0.26), radius: 30, y: 18)
            content
                .frame(width: 824, height: 824)
                .clipShape(tile)
        }
        .frame(width: 1024, height: 1024)
    }
}

// MARK: - Knob

private struct Knob: View {
    let dia: CGFloat = 144
    var body: some View {
        ZStack {
            // side wall, peeking below the face
            Circle()
                .fill(vGrad([P.knobWall, P.knobDeep]))
                .frame(width: dia, height: dia)
                .offset(y: 13)
            // top face
            Circle()
                .fill(vGrad([P.knobTop, P.knobBot])
                    .shadow(.inner(color: .white.opacity(0.9), radius: 2, y: 2))
                    .shadow(.inner(color: P.shadow.opacity(0.10), radius: 6, y: -5)))
                .frame(width: dia, height: dia)
                .overlay(
                    Ellipse()
                        .fill(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: dia * 0.72, height: dia * 0.40)
                        .offset(y: -dia * 0.17)
                        .blendMode(.softLight)
                )
                .overlay(Circle().strokeBorder(Color(hex: 0x34322B, 0.20), lineWidth: 1.5))
                .overlay(
                    Circle()
                        .fill(vGrad([P.amber, P.amberDeep]))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(P.ember.opacity(0.35), lineWidth: 1))
                )
        }
        .compositingGroup()
        .shadow(color: P.shadow.opacity(0.26), radius: 13, y: 9)
    }
}

// MARK: - Icon motif

private struct KelvinGradient: View {
    var detail: Bool = true            // ticks are dropped at tiny sizes
    private let track = Capsule()
    var body: some View {
        ZStack {
            // cool → warm colour-temperature track, recessed into the paper
            track
                .fill(LinearGradient(colors: [P.coolEdge, P.coolMid, P.warmMid, P.amber, P.amberDeep],
                                     startPoint: .leading, endPoint: .trailing)
                    .shadow(.inner(color: P.shadow.opacity(0.28), radius: 10, y: 6)))
                .frame(width: 604, height: 96)
                .overlay(track.strokeBorder(.black.opacity(0.06), lineWidth: 1.5))

            if detail {
                HStack(spacing: 46) {
                    ForEach(0..<10, id: \.self) { _ in
                        Capsule().fill(P.inkSoft.opacity(0.55)).frame(width: 6, height: 22)
                    }
                }
                .offset(y: 100)
            }

            // knob seated on the warm side, marking the current warmth
            Knob().offset(x: 116)
        }
        .frame(width: 824, height: 824)
        .offset(y: -6)
    }
}

private func iconView(px: Int) -> some View {
    FamilyTile { KelvinGradient(detail: px >= 96) }
}

// MARK: - Render harness (SwiftUI ImageRenderer, native per size)

private enum IconError: Error { case render(String) }

private let iconsetSizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

@MainActor
private func png(at px: Int) throws -> Data {
    let renderer = ImageRenderer(content: iconView(px: px))
    renderer.isOpaque = false
    renderer.scale = CGFloat(px) / 1024.0
    guard let cg = renderer.cgImage else { throw IconError.render("cgImage was nil at \(px)px") }
    let rep = NSBitmapImageRep(cgImage: cg)
    rep.size = NSSize(width: px, height: px)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw IconError.render("PNG encode failed at \(px)px")
    }
    return data
}

@MainActor
private func build() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let appiconset = CommandLine.arguments.dropFirst().first
        .map { URL(fileURLWithPath: $0) }
        ?? repoRoot.appendingPathComponent("Luma/Assets.xcassets/AppIcon.appiconset")

    let fm = FileManager.default
    try fm.createDirectory(at: appiconset, withIntermediateDirectories: true)

    var cache: [Int: Data] = [:]
    for (name, px) in iconsetSizes {
        let data = try cache[px] ?? png(at: px)
        cache[px] = data
        try data.write(to: appiconset.appendingPathComponent(name))
    }

    let master = repoRoot.appendingPathComponent("docs/luma-icon-1024.png")
    try fm.createDirectory(at: master.deletingLastPathComponent(), withIntermediateDirectories: true)
    try (cache[1024] ?? png(at: 1024)).write(to: master)

    print("✓ wrote \(appiconset.path) (10 sizes)")
    print("✓ wrote \(master.path)")
}

do {
    try MainActor.assumeIsolated { try build() }
} catch {
    FileHandle.standardError.write(Data("icon generation failed: \(error)\n".utf8))
    exit(1)
}
