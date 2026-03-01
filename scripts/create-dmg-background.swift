#!/usr/bin/env swift
// ABOUTME: Generates the background image for the DMG installer.
// ABOUTME: Creates a light background with a drag-to-install arrow between icon positions.

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

// Background — subtle vertical gradient, light enough for readable labels in both appearances
let topColor = CGColor(srgbRed: 0.93, green: 0.93, blue: 0.94, alpha: 1.0)
let bottomColor = CGColor(srgbRed: 0.86, green: 0.86, blue: 0.87, alpha: 1.0)
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

let arrowColor = CGColor(srgbRed: 0.55, green: 0.55, blue: 0.58, alpha: 1.0)
cg.setStrokeColor(arrowColor)
cg.setFillColor(arrowColor)
cg.setLineWidth(3)
cg.setLineCap(.round)
cg.setLineJoin(.round)

// Shaft
cg.move(to: CGPoint(x: startX, y: arrowY))
cg.addLine(to: CGPoint(x: endX - 14, y: arrowY))
cg.strokePath()

// Filled arrowhead
cg.move(to: CGPoint(x: endX - 20, y: arrowY + 12))
cg.addLine(to: CGPoint(x: endX, y: arrowY))
cg.addLine(to: CGPoint(x: endX - 20, y: arrowY - 12))
cg.closePath()
cg.fillPath()

NSGraphicsContext.current = nil

let data = rep.representation(using: .png, properties: [:])!
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "background.png"
try! data.write(to: URL(fileURLWithPath: outputPath))
