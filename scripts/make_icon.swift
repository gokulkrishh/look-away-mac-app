#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Usage: swift scripts/make_icon.swift <outputDir>
// Emits pixel-accurate icon_<size>.png for sizes 16, 32, 64, 128, 256, 512, 1024.
//
// Design: soft warm twilight gradient squircle with the SF Symbol
// `eyes.inverse` glyph centered in white.

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make_icon.swift <outputDir>\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// Minimal SVG path-data parser: supports M/m, C/c, Z/z (which is all this glyph uses).
func parseSVGPath(_ d: String) -> CGPath {
    let path = CGMutablePath()
    var i = d.startIndex
    var current = CGPoint.zero
    var subpathStart = CGPoint.zero

    func skipWS() {
        while i < d.endIndex, d[i].isWhitespace || d[i] == "," {
            i = d.index(after: i)
        }
    }
    func readNumber() -> CGFloat? {
        skipWS()
        var end = i
        while end < d.endIndex,
              d[end].isNumber || d[end] == "-" || d[end] == "." || d[end] == "e" || d[end] == "E" || d[end] == "+" {
            // Allow leading minus only as the first char of this token
            if d[end] == "-" && end != i { break }
            end = d.index(after: end)
        }
        let slice = d[i..<end]
        i = end
        return Double(slice).map { CGFloat($0) }
    }

    while i < d.endIndex {
        skipWS()
        guard i < d.endIndex else { break }
        let cmd = d[i]
        i = d.index(after: i)

        switch cmd {
        case "M", "m":
            let relative = (cmd == "m")
            guard let x = readNumber(), let y = readNumber() else { return path }
            current = relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            path.move(to: current)
            subpathStart = current
            // Subsequent coordinate pairs after M are treated as L (not used in this SVG).
        case "C", "c":
            let relative = (cmd == "c")
            while true {
                skipWS()
                guard i < d.endIndex, (d[i].isNumber || d[i] == "-" || d[i] == ".") else { break }
                guard let x1 = readNumber(), let y1 = readNumber(),
                      let x2 = readNumber(), let y2 = readNumber(),
                      let x = readNumber(),  let y = readNumber() else { return path }
                let c1: CGPoint
                let c2: CGPoint
                let end: CGPoint
                if relative {
                    c1 = CGPoint(x: current.x + x1, y: current.y + y1)
                    c2 = CGPoint(x: current.x + x2, y: current.y + y2)
                    end = CGPoint(x: current.x + x,  y: current.y + y)
                } else {
                    c1 = CGPoint(x: x1, y: y1)
                    c2 = CGPoint(x: x2, y: y2)
                    end = CGPoint(x: x,  y: y)
                }
                path.addCurve(to: end, control1: c1, control2: c2)
                current = end
            }
        case "Z", "z":
            path.closeSubpath()
            current = subpathStart
        default:
            // Unsupported command — advance and skip
            break
        }
    }
    return path
}

// Load the SF Symbol SVG path data once.
let scriptDir = URL(fileURLWithPath: args[0]).deletingLastPathComponent()
let svgURL = scriptDir.appendingPathComponent("eyes.inverse.svg")
let svgContent = (try? String(contentsOf: svgURL, encoding: .utf8)) ?? ""

// Extract the `d="..."` attribute. A single path element holds all subpaths.
func extractPathD(_ svg: String) -> String? {
    guard let dRange = svg.range(of: "d=\"") else { return nil }
    let start = dRange.upperBound
    guard let end = svg.range(of: "\"", range: start..<svg.endIndex)?.lowerBound else { return nil }
    return String(svg[start..<end])
}

guard let pathD = extractPathD(svgContent) else {
    FileHandle.standardError.write(Data("failed to extract SVG path data from \(svgURL.path)\n".utf8))
    exit(1)
}

let eyesSVGPath = parseSVGPath(pathD)
// SVG viewBox: 112.605 × 88.3495
let svgViewWidth: CGFloat = 112.605
let svgViewHeight: CGFloat = 88.3495

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

    // Flip Y so we can think in screen coordinates (y=0 is top).
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.2237
    let squircle = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Solid deep-indigo background — calm and high-contrast against white eyes.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.setFillColor(CGColor(srgbRed: 0.24, green: 0.18, blue: 0.48, alpha: 1)) // #3D2F7A
    ctx.fillPath()
    ctx.restoreGState()

    // Render the SF Symbol `eyes.inverse` glyph centered.
    // Glyph viewBox is wider than tall (1.27:1). Target ~58% of icon width.
    let targetWidth = size * 0.58
    let targetHeight = targetWidth * (svgViewHeight / svgViewWidth)
    let targetX = (size - targetWidth) / 2
    let targetY = (size - targetHeight) / 2

    var transform = CGAffineTransform.identity
    transform = transform.translatedBy(x: targetX, y: targetY)
    transform = transform.scaledBy(x: targetWidth / svgViewWidth, y: targetHeight / svgViewHeight)

    let transformedPath = CGMutablePath()
    transformedPath.addPath(eyesSVGPath, transform: transform)

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: size * 0.006),
        blur: size * 0.03,
        color: CGColor(srgbRed: 0.10, green: 0.08, blue: 0.20, alpha: 0.35)
    )
    ctx.addPath(transformedPath)
    ctx.setFillColor(CGColor(srgbRed: 1, green: 0.99, blue: 0.98, alpha: 1))
    ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()

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
