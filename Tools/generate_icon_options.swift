import AppKit
import Foundation

enum Concept: String, CaseIterable {
    case optionA = "option_a"
    case optionB = "option_b"
    case optionC = "option_c"
    case optionD = "option_d"

    var title: String {
        switch self {
        case .optionA: return "A"
        case .optionB: return "B"
        case .optionC: return "C"
        case .optionD: return "D"
        }
    }

    var background: [NSColor] {
        switch self {
        case .optionA:
            return [
                NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.23, alpha: 1),
                NSColor(calibratedRed: 0.14, green: 0.36, blue: 0.42, alpha: 1),
                NSColor(calibratedRed: 0.85, green: 0.83, blue: 0.72, alpha: 1),
            ]
        case .optionB:
            return [
                NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.18, alpha: 1),
                NSColor(calibratedRed: 0.17, green: 0.23, blue: 0.36, alpha: 1),
                NSColor(calibratedRed: 0.56, green: 0.66, blue: 0.72, alpha: 1),
            ]
        case .optionC:
            return [
                NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.16, alpha: 1),
                NSColor(calibratedRed: 0.20, green: 0.29, blue: 0.30, alpha: 1),
                NSColor(calibratedRed: 0.82, green: 0.74, blue: 0.62, alpha: 1),
            ]
        case .optionD:
            return [
                NSColor(calibratedRed: 0.11, green: 0.14, blue: 0.20, alpha: 1),
                NSColor(calibratedRed: 0.12, green: 0.31, blue: 0.38, alpha: 1),
                NSColor(calibratedRed: 0.72, green: 0.80, blue: 0.76, alpha: 1),
            ]
        }
    }

    var laptopRotation: CGFloat {
        switch self {
        case .optionA: return 0
        case .optionB: return -10
        case .optionC: return 7
        case .optionD: return -4
        }
    }

    var laptopScale: CGFloat {
        switch self {
        case .optionA: return 1.02
        case .optionB: return 0.96
        case .optionC: return 1.10
        case .optionD: return 1.00
        }
    }

    var laptopOffset: CGPoint {
        switch self {
        case .optionA: return CGPoint(x: 0, y: 18)
        case .optionB: return CGPoint(x: 14, y: 12)
        case .optionC: return CGPoint(x: -8, y: 38)
        case .optionD: return CGPoint(x: 0, y: 24)
        }
    }

    var hand: HandSpec {
        switch self {
        case .optionA:
            return HandSpec(anchor: CGPoint(x: 0.52, y: 0.36), angle: -14, scale: 0.98, side: .right, extendedFingers: 2)
        case .optionB:
            return HandSpec(anchor: CGPoint(x: 0.60, y: 0.39), angle: -28, scale: 0.92, side: .right, extendedFingers: 2)
        case .optionC:
            return HandSpec(anchor: CGPoint(x: 0.47, y: 0.34), angle: 8, scale: 1.05, side: .left, extendedFingers: 1)
        case .optionD:
            return HandSpec(anchor: CGPoint(x: 0.56, y: 0.36), angle: -8, scale: 0.96, side: .right, extendedFingers: 1)
        }
    }

    var cropEmphasis: CGFloat {
        switch self {
        case .optionA: return 1.0
        case .optionB: return 0.95
        case .optionC: return 1.12
        case .optionD: return 1.0
        }
    }
}

enum HandSide {
    case left
    case right
}

struct HandSpec {
    let anchor: CGPoint
    let angle: CGFloat
    let scale: CGFloat
    let side: HandSide
    let extendedFingers: Int
}

let fileManager = FileManager.default
let outputDirectory = URL(fileURLWithPath: "Designs/AppIconOptions", isDirectory: true)
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for concept in Concept.allCases {
    let url = outputDirectory.appendingPathComponent("\(concept.rawValue).png")
    try renderConcept(concept, size: 1024).pngData().write(to: url)
    print("wrote \(url.path)")
}

let sheetURL = outputDirectory.appendingPathComponent("comparison_sheet.png")
try renderComparisonSheet(size: 2200).pngData().write(to: sheetURL)
print("wrote \(sheetURL.path)")

func renderComparisonSheet(size: Int) -> NSBitmapImageRep {
    let rep = bitmap(size: size, height: size)
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let backgroundGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.16, alpha: 1),
    ])!
    backgroundGradient.draw(in: rect, angle: -32)

    let cardSize = CGFloat(size) * 0.40
    let margin = CGFloat(size) * 0.07
    let positions = [
        CGPoint(x: margin, y: CGFloat(size) - margin - cardSize),
        CGPoint(x: CGFloat(size) - margin - cardSize, y: CGFloat(size) - margin - cardSize),
        CGPoint(x: margin, y: margin),
        CGPoint(x: CGFloat(size) - margin - cardSize, y: margin),
    ]

    for (index, concept) in Concept.allCases.enumerated() {
        let cardRect = CGRect(origin: positions[index], size: CGSize(width: cardSize, height: cardSize))
        drawCard(for: concept, in: cardRect)
    }

    let title = "Trackpad Commander Icon Options"
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: CGFloat(size) * 0.03, weight: .semibold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.94),
        .paragraphStyle: paragraph,
    ]
    let titleRect = CGRect(x: 0, y: CGFloat(size) * 0.94, width: CGFloat(size), height: CGFloat(size) * 0.04)
    title.draw(in: titleRect, withAttributes: attributes)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func drawCard(for concept: Concept, in rect: CGRect) {
    let cardPath = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.06, yRadius: rect.width * 0.06)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = rect.width * 0.04
    shadow.shadowOffset = CGSize(width: 0, height: -rect.width * 0.02)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.set()
    NSColor.white.withAlphaComponent(0.08).setFill()
    cardPath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.12).setStroke()
    cardPath.lineWidth = rect.width * 0.004
    cardPath.stroke()

    let inset = rect.insetBy(dx: rect.width * 0.05, dy: rect.width * 0.08)
    let icon = renderConcept(concept, size: Int(inset.width))
    let image = NSImage(size: inset.size)
    image.addRepresentation(icon)
    image.draw(in: inset)

    let labelRect = CGRect(x: rect.minX, y: rect.minY + rect.width * 0.01, width: rect.width, height: rect.width * 0.07)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: rect.width * 0.05, weight: .bold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.96),
        .paragraphStyle: paragraph,
    ]
    "Option \(concept.title)".draw(in: labelRect, withAttributes: attributes)
}

func renderConcept(_ concept: Concept, size: Int) -> NSBitmapImageRep {
    let rep = bitmap(size: size, height: size)
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let ctx = context.cgContext
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    configure(context: ctx, rect: rect)

    drawBackground(for: concept, rect: rect, context: ctx)
    drawLaptopScene(for: concept, rect: rect, context: ctx)
    drawHand(spec: concept.hand, rect: rect, context: ctx)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func bitmap(size: Int, height: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
}

func configure(context ctx: CGContext, rect: CGRect) {
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.translateBy(x: 0, y: rect.height)
    ctx.scaleBy(x: 1, y: -1)
}

func drawBackground(for concept: Concept, rect: CGRect, context ctx: CGContext) {
    let frame = rect.insetBy(dx: rect.width * 0.035, dy: rect.width * 0.035)
    let rounded = CGPath(roundedRect: frame, cornerWidth: rect.width * 0.22, cornerHeight: rect.width * 0.22, transform: nil)

    ctx.saveGState()
    ctx.addPath(rounded)
    ctx.clip()
    fillGradient(
        ctx,
        rect: frame,
        colors: concept.background.map(\.cgColor),
        start: CGPoint(x: frame.minX, y: frame.maxY),
        end: CGPoint(x: frame.maxX, y: frame.minY)
    )

    ctx.setBlendMode(.screen)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.10).cgColor)
    ctx.fillEllipse(in: CGRect(x: rect.width * 0.56, y: rect.height * 0.06, width: rect.width * 0.32, height: rect.width * 0.32))
    ctx.setFillColor(NSColor(calibratedRed: 0.27, green: 0.72, blue: 0.98, alpha: 0.14).cgColor)
    ctx.fillEllipse(in: CGRect(x: rect.width * 0.02, y: rect.height * 0.58, width: rect.width * 0.46, height: rect.width * 0.38))
    ctx.setBlendMode(.normal)
    ctx.restoreGState()

    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
    ctx.setLineWidth(rect.width * 0.012)
    ctx.addPath(rounded)
    ctx.strokePath()
}

func drawLaptopScene(for concept: Concept, rect: CGRect, context ctx: CGContext) {
    ctx.saveGState()

    let center = CGPoint(x: rect.midX + concept.laptopOffset.x, y: rect.midY + concept.laptopOffset.y)
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: concept.laptopRotation * (.pi / 180))
    ctx.scaleBy(x: concept.laptopScale * concept.cropEmphasis, y: concept.laptopScale * concept.cropEmphasis)
    ctx.translateBy(x: -center.x, y: -center.y)

    let body = CGRect(x: rect.width * 0.14, y: rect.height * 0.25, width: rect.width * 0.72, height: rect.height * 0.46)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: rect.width * 0.05, cornerHeight: rect.width * 0.05, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: rect.width * 0.02), blur: rect.width * 0.06, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(bodyPath)
    ctx.clip()
    fillGradient(
        ctx,
        rect: body,
        colors: [
            NSColor(calibratedRed: 0.44, green: 0.47, blue: 0.50, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.27, green: 0.29, blue: 0.33, alpha: 1).cgColor,
        ],
        start: CGPoint(x: body.minX, y: body.maxY),
        end: CGPoint(x: body.maxX, y: body.minY)
    )
    ctx.restoreGState()

    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
    ctx.setLineWidth(rect.width * 0.006)
    ctx.addPath(bodyPath)
    ctx.strokePath()

    let keyboardArea = CGRect(x: rect.width * 0.20, y: rect.height * 0.35, width: rect.width * 0.60, height: rect.height * 0.15)
    drawKeyboard(in: keyboardArea, context: ctx, iconSize: rect.width)

    let trackpad = CGRect(x: rect.width * 0.34, y: rect.height * 0.53, width: rect.width * 0.32, height: rect.height * 0.15)
    let trackpadPath = CGPath(roundedRect: trackpad, cornerWidth: rect.width * 0.028, cornerHeight: rect.width * 0.028, transform: nil)
    fillGradient(
        ctx,
        rect: trackpad,
        colors: [
            NSColor(calibratedRed: 0.58, green: 0.61, blue: 0.64, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.36, green: 0.39, blue: 0.43, alpha: 1).cgColor,
        ],
        start: CGPoint(x: trackpad.minX, y: trackpad.maxY),
        end: CGPoint(x: trackpad.maxX, y: trackpad.minY)
    )
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
    ctx.setLineWidth(rect.width * 0.006)
    ctx.addPath(trackpadPath)
    ctx.strokePath()

    let touchPoint = CGPoint(x: trackpad.midX, y: trackpad.midY - rect.width * 0.005)
    drawTapRipple(center: touchPoint, size: rect.width * 0.13, context: ctx)

    let bezel = CGRect(x: rect.width * 0.19, y: rect.height * 0.16, width: rect.width * 0.62, height: rect.height * 0.08)
    let bezelPath = CGPath(roundedRect: bezel, cornerWidth: rect.width * 0.02, cornerHeight: rect.width * 0.02, transform: nil)
    fillGradient(
        ctx,
        rect: bezel,
        colors: [
            NSColor(calibratedRed: 0.21, green: 0.23, blue: 0.26, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1).cgColor,
        ],
        start: CGPoint(x: bezel.minX, y: bezel.maxY),
        end: CGPoint(x: bezel.maxX, y: bezel.minY)
    )
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
    ctx.setLineWidth(rect.width * 0.005)
    ctx.addPath(bezelPath)
    ctx.strokePath()

    let screen = bezel.insetBy(dx: rect.width * 0.012, dy: rect.width * 0.010)
    fillGradient(
        ctx,
        rect: screen,
        colors: [
            NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.45, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.06, green: 0.17, blue: 0.27, alpha: 1).cgColor,
        ],
        start: CGPoint(x: screen.minX, y: screen.maxY),
        end: CGPoint(x: screen.maxX, y: screen.minY)
    )

    let highlight = CGRect(x: body.minX + rect.width * 0.03, y: body.minY + rect.height * 0.03, width: body.width - rect.width * 0.06, height: rect.height * 0.035)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.05).cgColor)
    ctx.addPath(CGPath(roundedRect: highlight, cornerWidth: highlight.height / 2, cornerHeight: highlight.height / 2, transform: nil))
    ctx.fillPath()

    ctx.restoreGState()
}

func drawKeyboard(in rect: CGRect, context ctx: CGContext, iconSize: CGFloat) {
    let rows = 4
    let columns = 9
    let gapX = rect.width * 0.018
    let gapY = rect.height * 0.09
    let keyWidth = (rect.width - gapX * CGFloat(columns - 1)) / CGFloat(columns)
    let keyHeight = (rect.height - gapY * CGFloat(rows - 1)) / CGFloat(rows)

    for row in 0..<rows {
        for column in 0..<columns {
            let widthMultiplier: CGFloat = (row == 3 && (column == 0 || column == 8)) ? 1.35 : 1.0
            let w = keyWidth * widthMultiplier
            let x = rect.minX + CGFloat(column) * (keyWidth + gapX)
            let y = rect.minY + CGFloat(row) * (keyHeight + gapY)
            let keyRect = CGRect(x: x, y: y, width: min(w, rect.maxX - x), height: keyHeight)
            let path = CGPath(roundedRect: keyRect, cornerWidth: iconSize * 0.008, cornerHeight: iconSize * 0.008, transform: nil)
            fillGradient(
                ctx,
                rect: keyRect,
                colors: [
                    NSColor(calibratedRed: 0.19, green: 0.20, blue: 0.23, alpha: 1).cgColor,
                    NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1).cgColor,
                ],
                start: CGPoint(x: keyRect.minX, y: keyRect.maxY),
                end: CGPoint(x: keyRect.maxX, y: keyRect.minY)
            )
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.05).cgColor)
            ctx.setLineWidth(iconSize * 0.0025)
            ctx.addPath(path)
            ctx.strokePath()
        }
    }
}

func drawTapRipple(center: CGPoint, size: CGFloat, context ctx: CGContext) {
    for index in 0..<3 {
        let radius = size * (0.18 + CGFloat(index) * 0.18)
        let alpha = 0.30 - CGFloat(index) * 0.08
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.setStrokeColor(NSColor(calibratedRed: 0.58, green: 0.90, blue: 1.0, alpha: alpha).cgColor)
        ctx.setLineWidth(size * 0.04)
        ctx.strokeEllipse(in: rect)
    }

    ctx.setFillColor(NSColor.white.withAlphaComponent(0.75).cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - size * 0.05, y: center.y - size * 0.05, width: size * 0.10, height: size * 0.10))
}

func drawHand(spec: HandSpec, rect: CGRect, context ctx: CGContext) {
    ctx.saveGState()

    let anchor = CGPoint(x: rect.width * spec.anchor.x, y: rect.height * spec.anchor.y)
    ctx.translateBy(x: anchor.x, y: anchor.y)
    ctx.rotate(by: spec.angle * (.pi / 180))
    ctx.scaleBy(x: spec.side == .right ? 1 : -1, y: 1)
    ctx.scaleBy(x: spec.scale, y: spec.scale)

    let palm = CGRect(x: -rect.width * 0.11, y: -rect.height * 0.05, width: rect.width * 0.25, height: rect.height * 0.22)
    let palmPath = CGPath(roundedRect: palm, cornerWidth: rect.width * 0.06, cornerHeight: rect.width * 0.06, transform: nil)
    fillSkin(on: ctx, rect: palm, path: palmPath)

    let fingerWidths: [CGFloat] = [0.070, 0.056, 0.050]
    let fingerHeights: [CGFloat] = [0.24, 0.18, 0.16]
    let fingerOffsets: [CGFloat] = [-0.02, 0.04, 0.09]

    for index in 0..<spec.extendedFingers {
        let finger = CGRect(
            x: rect.width * fingerOffsets[index],
            y: -rect.height * (0.02 + CGFloat(index) * 0.005),
            width: rect.width * fingerWidths[index],
            height: rect.height * fingerHeights[index]
        )
        let fingerPath = CGPath(roundedRect: finger, cornerWidth: finger.width / 2, cornerHeight: finger.width / 2, transform: nil)
        fillSkin(on: ctx, rect: finger, path: fingerPath)

        let nail = CGRect(x: finger.minX + finger.width * 0.17, y: finger.minY + finger.height * 0.08, width: finger.width * 0.66, height: finger.height * 0.18)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.24).cgColor)
        ctx.addPath(CGPath(roundedRect: nail, cornerWidth: nail.height / 2, cornerHeight: nail.height / 2, transform: nil))
        ctx.fillPath()
    }

    let thumb = CGRect(x: -rect.width * 0.13, y: rect.height * 0.02, width: rect.width * 0.08, height: rect.height * 0.15)
    let thumbPath = CGPath(roundedRect: thumb, cornerWidth: thumb.width / 2, cornerHeight: thumb.width / 2, transform: nil)
    fillSkin(on: ctx, rect: thumb, path: thumbPath)

    let knuckleGlow = CGRect(x: -rect.width * 0.08, y: rect.height * 0.01, width: rect.width * 0.17, height: rect.height * 0.07)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.10).cgColor)
    ctx.fillEllipse(in: knuckleGlow)

    ctx.restoreGState()
}

func fillSkin(on ctx: CGContext, rect: CGRect, path: CGPath) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: rect.height * 0.03), blur: rect.height * 0.06, color: NSColor.black.withAlphaComponent(0.20).cgColor)
    ctx.addPath(path)
    ctx.clip()
    fillGradient(
        ctx,
        rect: rect,
        colors: [
            NSColor(calibratedRed: 0.98, green: 0.83, blue: 0.69, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.91, green: 0.70, blue: 0.56, alpha: 1).cgColor,
        ],
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY)
    )
    ctx.restoreGState()

    ctx.setStrokeColor(NSColor(calibratedRed: 0.73, green: 0.52, blue: 0.40, alpha: 0.55).cgColor)
    ctx.setLineWidth(max(rect.width * 0.03, 2))
    ctx.addPath(path)
    ctx.strokePath()
}

func fillGradient(_ ctx: CGContext, rect: CGRect, colors: [CGColor], start: CGPoint, end: CGPoint) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil) else {
        return
    }

    ctx.saveGState()
    ctx.addRect(rect)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
    ctx.restoreGState()
}

extension NSBitmapImageRep {
    func pngData() throws -> Data {
        guard let data = representation(using: .png, properties: [:]) else {
            throw NSError(domain: "IconOptions", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG data"])
        }
        return data
    }
}
