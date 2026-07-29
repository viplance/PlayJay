import AppKit
import Foundation

private let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: outputDirectory)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

private struct IconBitmap {
    let name: String
    let size: Int
}

private let bitmaps: [IconBitmap] = [
    .init(name: "icon_16x16.png", size: 16),
    .init(name: "icon_16x16@2x.png", size: 32),
    .init(name: "icon_32x32.png", size: 32),
    .init(name: "icon_32x32@2x.png", size: 64),
    .init(name: "icon_128x128.png", size: 128),
    .init(name: "icon_128x128@2x.png", size: 256),
    .init(name: "icon_256x256.png", size: 256),
    .init(name: "icon_256x256@2x.png", size: 512),
    .init(name: "icon_512x512.png", size: 512),
    .init(name: "icon_512x512@2x.png", size: 1024)
]

private func drawIcon(size: Int) -> NSImage {
    let dimension = CGFloat(size)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high

    let fullRect = NSRect(x: 0, y: 0, width: dimension, height: dimension)
    NSColor.clear.setFill()
    fullRect.fill()

    let scale = dimension / 1024.0
    func r(_ value: CGFloat) -> CGFloat { value * scale }
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: r(x), y: r(y), width: r(width), height: r(height))
    }

    // Background rounded rect
    let body = rect(64, 64, 896, 896)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: r(206), yRadius: r(206))

    // Dark black/charcoal gradient for the body
    let background = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1),
        NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.18, alpha: 1)
    ])
    background?.draw(in: bodyPath, angle: -45)

    // Subtle border
    NSColor(calibratedWhite: 1, alpha: 0.12).setStroke()
    bodyPath.lineWidth = r(6)
    bodyPath.stroke()

    // Draw diagonal jay-wing stripes in top-left corner
    NSGraphicsContext.current?.saveGraphicsState()
    bodyPath.addClip()
    
    let stripeColors = [
        NSColor(calibratedRed: 0.76, green: 0.59, blue: 0.53, alpha: 1.0), // Red-Beige (body)
        NSColor(calibratedWhite: 0.05, alpha: 1.0),                        // Black
        NSColor.white,                                                     // White
        NSColor(calibratedRed: 0.12, green: 0.53, blue: 0.90, alpha: 1.0)  // Jay Blue
    ]
    
    var offset: CGFloat = 120
    let stripeWidth: CGFloat = 42
    for color in stripeColors {
        let stripePath = NSBezierPath()
        stripePath.move(to: NSPoint(x: r(64), y: r(960 - offset)))
        stripePath.line(to: NSPoint(x: r(64 + offset), y: r(960)))
        stripePath.line(to: NSPoint(x: r(64 + offset + stripeWidth), y: r(960)))
        stripePath.line(to: NSPoint(x: r(64), y: r(960 - offset - stripeWidth)))
        stripePath.close()
        
        color.setFill()
        stripePath.fill()
        
        offset += stripeWidth
    }
    
    NSGraphicsContext.current?.restoreGraphicsState()

    // Ambient glow behind play button (Jay Blue)
    let glowPath = NSBezierPath(ovalIn: rect(220, 220, 584, 584))
    NSColor(calibratedRed: 0.12, green: 0.53, blue: 0.90, alpha: 0.16).setFill()
    glowPath.fill()

    // Disc circle
    let discCenter = NSPoint(x: r(512), y: r(512))
    let discRadius = r(260)
    let discPath = NSBezierPath(ovalIn: NSRect(
        x: discCenter.x - discRadius,
        y: discCenter.y - discRadius,
        width: discRadius * 2,
        height: discRadius * 2
    ))
    NSColor(calibratedWhite: 0, alpha: 0.45).setFill()
    discPath.fill()
    NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
    discPath.lineWidth = r(4)
    discPath.stroke()

    // Inner ring grooves
    for groove in [180, 130, 80] as [CGFloat] {
        let grooveRadius = r(groove)
        let groovePath = NSBezierPath(ovalIn: NSRect(
            x: discCenter.x - grooveRadius,
            y: discCenter.y - grooveRadius,
            width: grooveRadius * 2,
            height: grooveRadius * 2
        ))
        NSColor(calibratedWhite: 1, alpha: 0.05).setStroke()
        groovePath.lineWidth = r(1.5)
        groovePath.stroke()
    }

    // Center dot (Red-Beige)
    let dotRadius = r(28)
    let dotPath = NSBezierPath(ovalIn: NSRect(
        x: discCenter.x - dotRadius,
        y: discCenter.y - dotRadius,
        width: dotRadius * 2,
        height: dotRadius * 2
    ))
    NSColor(calibratedRed: 0.76, green: 0.59, blue: 0.53, alpha: 1).setFill()
    dotPath.fill()

    // Play triangle (Jay Blue gradient)
    let triPath = NSBezierPath()
    triPath.move(to: NSPoint(x: r(440), y: r(380)))
    triPath.line(to: NSPoint(x: r(440), y: r(644)))
    triPath.line(to: NSPoint(x: r(640), y: r(512)))
    triPath.close()

    let triGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.12, green: 0.53, blue: 0.90, alpha: 1),
        NSColor(calibratedRed: 0.25, green: 0.68, blue: 1.0, alpha: 1)
    ])
    triGradient?.draw(in: triPath, angle: 90)

    // Sound wave arcs (right side) in Jay Blue
    for (offset, alpha) in [(40, 0.7), (80, 0.5), (120, 0.3)] as [(CGFloat, CGFloat)] {
        let arcPath = NSBezierPath()
        let centerX = r(640 + offset)
        let centerY = r(512)
        let arcRadius = r(60 + offset)
        arcPath.appendArc(
            withCenter: NSPoint(x: centerX, y: centerY),
            radius: arcRadius,
            startAngle: -35,
            endAngle: 35
        )
        NSColor(calibratedRed: 0.12, green: 0.53, blue: 0.90, alpha: alpha).setStroke()
        arcPath.lineWidth = r(12)
        arcPath.lineCapStyle = .round
        arcPath.stroke()
    }

    // "J" letter badge (bottom-right) in Red-Beige
    let badgeCx = r(770)
    let badgeCy = r(240)
    let badgeR = r(72)
    let badgePath = NSBezierPath(ovalIn: NSRect(
        x: badgeCx - badgeR, y: badgeCy - badgeR,
        width: badgeR * 2, height: badgeR * 2
    ))
    NSColor(calibratedRed: 0.76, green: 0.59, blue: 0.53, alpha: 1).setFill()
    badgePath.fill()
    NSColor(calibratedWhite: 1, alpha: 0.25).setStroke()
    badgePath.lineWidth = r(4)
    badgePath.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: r(78), weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    NSString(string: "J").draw(in: NSRect(
        x: badgeCx - badgeR, y: badgeCy - r(42),
        width: badgeR * 2, height: r(90)
    ), withAttributes: attrs)

    return image
}

private func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try png.write(to: url)
}

for bitmap in bitmaps {
    let image = drawIcon(size: bitmap.size)
    try writePNG(image, to: outputDirectory.appendingPathComponent(bitmap.name))
}

print(outputDirectory.path)
