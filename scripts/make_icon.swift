#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Usage: swift scripts/make_icon.swift <outputDir>
// Emits pixel-accurate icon_<size>.png for sizes 16, 32, 64, 128, 256, 512, 1024.

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make_icon.swift <outputDir>\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

func drawIcon(pixelSize: Int) -> Data? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let size = CGFloat(pixelSize)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Continuous-corner squircle
    let cornerRadius = size * 0.2237
    let squircle = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // Diagonal gradient: soft periwinkle → deep violet
    let gradientColors = [
        CGColor(srgbRed: 0.42, green: 0.48, blue: 0.85, alpha: 1),
        CGColor(srgbRed: 0.20, green: 0.18, blue: 0.45, alpha: 1)
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    // Soft inner highlight for depth
    let highlightColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.22),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)
    ] as CFArray
    let highlight = CGGradient(colorsSpace: colorSpace, colors: highlightColors, locations: [0, 1])!
    ctx.drawRadialGradient(
        highlight,
        startCenter: CGPoint(x: size * 0.25, y: size * 0.78), startRadius: 0,
        endCenter: CGPoint(x: size * 0.25, y: size * 0.78), endRadius: size * 0.65,
        options: []
    )
    ctx.restoreGState()

    // Eye — almond + pupil + catchlight
    let eyeWidth = size * 0.66
    let eyeHeight = size * 0.36
    let cx = size / 2
    let cy = size / 2
    let eyeRect = CGRect(x: cx - eyeWidth / 2, y: cy - eyeHeight / 2, width: eyeWidth, height: eyeHeight)

    let eyePath = CGMutablePath()
    eyePath.move(to: CGPoint(x: eyeRect.minX, y: eyeRect.midY))
    eyePath.addQuadCurve(
        to: CGPoint(x: eyeRect.maxX, y: eyeRect.midY),
        control: CGPoint(x: eyeRect.midX, y: eyeRect.maxY + eyeHeight * 0.1)
    )
    eyePath.addQuadCurve(
        to: CGPoint(x: eyeRect.minX, y: eyeRect.midY),
        control: CGPoint(x: eyeRect.midX, y: eyeRect.minY - eyeHeight * 0.1)
    )
    eyePath.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.006),
        blur: size * 0.02,
        color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.25)
    )
    ctx.addPath(eyePath)
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.97))
    ctx.fillPath()
    ctx.restoreGState()

    let pupilRadius = eyeHeight * 0.32
    let pupilRect = CGRect(x: cx - pupilRadius, y: cy - pupilRadius, width: pupilRadius * 2, height: pupilRadius * 2)
    ctx.setFillColor(CGColor(srgbRed: 0.15, green: 0.14, blue: 0.36, alpha: 1))
    ctx.fillEllipse(in: pupilRect)

    let catchRadius = pupilRadius * 0.35
    let catchRect = CGRect(
        x: pupilRect.midX + pupilRadius * 0.18,
        y: pupilRect.midY + pupilRadius * 0.18,
        width: catchRadius * 2,
        height: catchRadius * 2
    )
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
    ctx.fillEllipse(in: catchRect)

    guard let cgImage = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    return rep.representation(using: .png, properties: [:])
}

for size in sizes {
    guard let data = drawIcon(pixelSize: size) else {
        FileHandle.standardError.write(Data("failed \(size)\n".utf8))
        exit(1)
    }
    let url = outDir.appendingPathComponent("icon_\(size).png")
    try data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(size)x\(size))")
}
