import AppKit
import Foundation

struct IconSpec {
    let size: Int
    let filename: String
}

let specs: [IconSpec] = [
    .init(size: 16, filename: "icon_16x16.png"),
    .init(size: 32, filename: "icon_16x16@2x.png"),
    .init(size: 32, filename: "icon_32x32.png"),
    .init(size: 64, filename: "icon_32x32@2x.png"),
    .init(size: 128, filename: "icon_128x128.png"),
    .init(size: 256, filename: "icon_128x128@2x.png"),
    .init(size: 256, filename: "icon_256x256.png"),
    .init(size: 512, filename: "icon_256x256@2x.png"),
    .init(size: 512, filename: "icon_512x512.png"),
    .init(size: 1024, filename: "icon_512x512@2x.png"),
]

let fileManager = FileManager.default
let outputDirectory = URL(fileURLWithPath: "TrackpadCommander/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    let url = outputDirectory.appendingPathComponent(spec.filename)
    try renderIcon(size: spec.size).pngData().write(to: url)
    print("wrote \(url.path)")
}

func renderIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let ctx = context.cgContext
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = rect.width

    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.translateBy(x: 0, y: rect.height)
    ctx.scaleBy(x: 1, y: -1)

    drawBackground(in: ctx, rect: rect, scale: scale)
    drawLaptop(in: ctx, rect: rect, scale: scale)
    drawTouches(in: ctx, rect: rect, scale: scale)
    drawFingers(in: ctx, rect: rect, scale: scale)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func drawBackground(in ctx: CGContext, rect: CGRect, scale: CGFloat) {
    let corner = scale * 0.23
    let backgroundPath = CGPath(roundedRect: rect.insetBy(dx: scale * 0.035, dy: scale * 0.035), cornerWidth: corner, cornerHeight: corner, transform: nil)

    ctx.saveGState()
    ctx.addPath(backgroundPath)
    ctx.clip()

    fillLinearGradient(
        in: ctx,
        rect: rect,
        colors: [
            NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.25, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.07, green: 0.44, blue: 0.55, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.37, alpha: 1).cgColor,
        ],
        locations: [0, 0.58, 1],
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY)
    )

    ctx.setBlendMode(.screen)
    ctx.setFillColor(NSColor(calibratedRed: 0.45, green: 0.83, blue: 0.95, alpha: 0.18).cgColor)
    ctx.fillEllipse(in: CGRect(x: scale * 0.03, y: scale * 0.58, width: scale * 0.45, height: scale * 0.36))

    ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.9, alpha: 0.12).cgColor)
    ctx.fillEllipse(in: CGRect(x: scale * 0.52, y: scale * 0.08, width: scale * 0.40, height: scale * 0.34))

    ctx.setBlendMode(.normal)
    ctx.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.12).cgColor)
    ctx.setLineWidth(scale * 0.012)
    ctx.addPath(backgroundPath)
    ctx.strokePath()
    ctx.restoreGState()
}

func drawLaptop(in ctx: CGContext, rect: CGRect, scale: CGFloat) {
    let screenFrame = CGRect(x: scale * 0.25, y: scale * 0.13, width: scale * 0.50, height: scale * 0.13)
    let screenPath = CGPath(roundedRect: screenFrame, cornerWidth: scale * 0.035, cornerHeight: scale * 0.035, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: scale * 0.018), blur: scale * 0.032, color: NSColor(calibratedWhite: 0, alpha: 0.22).cgColor)
    ctx.addPath(screenPath)
    ctx.setFillColor(NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.18, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    let screenGlow = screenFrame.insetBy(dx: scale * 0.014, dy: scale * 0.014)
    fillLinearGradient(
        in: ctx,
        rect: screenGlow,
        colors: [
            NSColor(calibratedRed: 0.24, green: 0.83, blue: 0.97, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.11, green: 0.44, blue: 0.71, alpha: 1).cgColor,
        ],
        locations: [0, 1],
        start: CGPoint(x: screenGlow.midX, y: screenGlow.maxY),
        end: CGPoint(x: screenGlow.midX, y: screenGlow.minY)
    )

    let hinge = CGRect(x: scale * 0.42, y: scale * 0.285, width: scale * 0.16, height: scale * 0.018)
    ctx.setFillColor(NSColor(calibratedRed: 0.22, green: 0.25, blue: 0.32, alpha: 1).cgColor)
    ctx.addPath(CGPath(roundedRect: hinge, cornerWidth: hinge.height / 2, cornerHeight: hinge.height / 2, transform: nil))
    ctx.fillPath()

    let baseFrame = CGRect(x: scale * 0.11, y: scale * 0.31, width: scale * 0.78, height: scale * 0.42)
    let basePath = CGPath(roundedRect: baseFrame, cornerWidth: scale * 0.06, cornerHeight: scale * 0.06, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: scale * 0.02), blur: scale * 0.05, color: NSColor(calibratedWhite: 0, alpha: 0.22).cgColor)
    ctx.addPath(basePath)
    ctx.clip()
    fillLinearGradient(
        in: ctx,
        rect: baseFrame,
        colors: [
            NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.0, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.79, green: 0.84, blue: 0.91, alpha: 1).cgColor,
        ],
        locations: [0, 1],
        start: CGPoint(x: baseFrame.minX, y: baseFrame.maxY),
        end: CGPoint(x: baseFrame.maxX, y: baseFrame.minY)
    )
    ctx.restoreGState()

    ctx.setStrokeColor(NSColor(calibratedRed: 0.46, green: 0.52, blue: 0.62, alpha: 0.55).cgColor)
    ctx.setLineWidth(scale * 0.007)
    ctx.addPath(basePath)
    ctx.strokePath()

    let keyboardShelf = CGRect(x: scale * 0.18, y: scale * 0.42, width: scale * 0.64, height: scale * 0.055)
    ctx.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.42).cgColor)
    ctx.addPath(CGPath(roundedRect: keyboardShelf, cornerWidth: scale * 0.03, cornerHeight: scale * 0.03, transform: nil))
    ctx.fillPath()

    let trackpad = CGRect(x: scale * 0.28, y: scale * 0.50, width: scale * 0.44, height: scale * 0.17)
    let trackpadPath = CGPath(roundedRect: trackpad, cornerWidth: scale * 0.04, cornerHeight: scale * 0.04, transform: nil)
    fillLinearGradient(
        in: ctx,
        rect: trackpad,
        colors: [
            NSColor(calibratedRed: 0.86, green: 0.90, blue: 0.96, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.68, green: 0.75, blue: 0.85, alpha: 1).cgColor,
        ],
        locations: [0, 1],
        start: CGPoint(x: trackpad.minX, y: trackpad.maxY),
        end: CGPoint(x: trackpad.maxX, y: trackpad.minY)
    )
    ctx.setStrokeColor(NSColor(calibratedRed: 0.36, green: 0.46, blue: 0.6, alpha: 0.6).cgColor)
    ctx.setLineWidth(scale * 0.006)
    ctx.addPath(trackpadPath)
    ctx.strokePath()
}

func drawTouches(in ctx: CGContext, rect: CGRect, scale: CGFloat) {
    let centers = [0.40, 0.50, 0.60].map { CGPoint(x: scale * $0, y: scale * 0.585) }
    for center in centers {
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        ctx.setFillColor(NSColor(calibratedRed: 0.24, green: 0.84, blue: 1.0, alpha: 0.18).cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - scale * 0.045, y: center.y - scale * 0.045, width: scale * 0.09, height: scale * 0.09))
        ctx.restoreGState()

        ctx.setStrokeColor(NSColor(calibratedRed: 0.16, green: 0.76, blue: 0.97, alpha: 0.7).cgColor)
        ctx.setLineWidth(scale * 0.008)
        ctx.strokeEllipse(in: CGRect(x: center.x - scale * 0.022, y: center.y - scale * 0.022, width: scale * 0.044, height: scale * 0.044))

        ctx.setFillColor(NSColor(calibratedRed: 0.96, green: 0.99, blue: 1.0, alpha: 0.85).cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - scale * 0.010, y: center.y - scale * 0.010, width: scale * 0.02, height: scale * 0.02))
    }
}

func drawFingers(in ctx: CGContext, rect: CGRect, scale: CGFloat) {
    let centers: [CGFloat] = [0.39, 0.50, 0.61]
    let widths: [CGFloat] = [0.10, 0.11, 0.10]
    let heights: [CGFloat] = [0.54, 0.58, 0.54]
    let topOffsets: [CGFloat] = [0.05, 0.03, 0.05]

    for index in centers.indices {
        let width = scale * widths[index]
        let height = scale * heights[index]
        let x = scale * centers[index] - width / 2
        let y = scale * topOffsets[index]

        let bodyRect = CGRect(x: x, y: y, width: width, height: height)
        let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: width / 2, cornerHeight: width / 2, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: scale * 0.012), blur: scale * 0.03, color: NSColor(calibratedWhite: 0, alpha: 0.18).cgColor)
        ctx.addPath(bodyPath)
        ctx.clip()
        fillLinearGradient(
            in: ctx,
            rect: bodyRect,
            colors: [
                NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.72, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.94, green: 0.67, blue: 0.52, alpha: 1).cgColor,
            ],
            locations: [0, 1],
            start: CGPoint(x: bodyRect.midX, y: bodyRect.maxY),
            end: CGPoint(x: bodyRect.midX, y: bodyRect.minY)
        )
        ctx.restoreGState()

        ctx.setStrokeColor(NSColor(calibratedRed: 0.74, green: 0.44, blue: 0.31, alpha: 0.45).cgColor)
        ctx.setLineWidth(scale * 0.005)
        ctx.addPath(bodyPath)
        ctx.strokePath()

        let nailRect = CGRect(x: x + width * 0.18, y: y + height * 0.69, width: width * 0.64, height: height * 0.17)
        ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.92, alpha: 0.45).cgColor)
        ctx.addPath(CGPath(roundedRect: nailRect, cornerWidth: nailRect.height / 2, cornerHeight: nailRect.height / 2, transform: nil))
        ctx.fillPath()

        let tipHighlight = CGRect(x: x + width * 0.10, y: y + height * 0.03, width: width * 0.80, height: height * 0.22)
        ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.82, alpha: 0.42).cgColor)
        ctx.addPath(CGPath(roundedRect: tipHighlight, cornerWidth: tipHighlight.height / 2, cornerHeight: tipHighlight.height / 2, transform: nil))
        ctx.fillPath()
    }
}

func fillLinearGradient(
    in ctx: CGContext,
    rect: CGRect,
    colors: [CGColor],
    locations: [CGFloat],
    start: CGPoint,
    end: CGPoint
) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)
    else {
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
            throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG data"])
        }
        return data
    }
}
