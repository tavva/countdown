#!/usr/bin/env swift
// ABOUTME: Generates the background image for the DMG installer.
// ABOUTME: Creates a dark background with a drag-to-install arrow between icon positions.

import AppKit

let width: CGFloat = 660
let height: CGFloat = 400

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width),
    pixelsHigh: Int(height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!
let cg = NSGraphicsContext.current!.cgContext

// Background — subtle vertical gradient
let topColor = CGColor(srgbRed: 0.16, green: 0.16, blue: 0.17, alpha: 1.0)
let bottomColor = CGColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [topColor, bottomColor] as CFArray,
    locations: [0.0, 1.0]
)!
cg.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: height),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// Arrow between icon positions
// Icons at (180, 190) and (480, 190) from top-left in Finder
// CG origin is bottom-left, so y = 400 - 190 = 210
let arrowY: CGFloat = 210
let startX: CGFloat = 250
let endX: CGFloat = 415

let arrowColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.45)
cg.setStrokeColor(arrowColor)
cg.setLineWidth(4)
cg.setLineCap(.round)
cg.setLineJoin(.round)

// Shaft
cg.move(to: CGPoint(x: startX, y: arrowY))
cg.addLine(to: CGPoint(x: endX - 18, y: arrowY))
cg.strokePath()

// Arrowhead (chevron)
cg.move(to: CGPoint(x: endX - 30, y: arrowY + 16))
cg.addLine(to: CGPoint(x: endX, y: arrowY))
cg.addLine(to: CGPoint(x: endX - 30, y: arrowY - 16))
cg.strokePath()

NSGraphicsContext.current = nil

let data = rep.representation(using: .png, properties: [:])!
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "background.png"
try! data.write(to: URL(fileURLWithPath: outputPath))
