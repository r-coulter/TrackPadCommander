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

let sourceURL = URL(fileURLWithPath: "iconIdea.png")
let croppedPreviewURL = URL(fileURLWithPath: "Designs/AppIconOptions/iconIdea_cropped.png")
let appIconDirectory = URL(fileURLWithPath: "TrackpadCommander/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

let fileManager = FileManager.default
try fileManager.createDirectory(at: croppedPreviewURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try fileManager.createDirectory(at: appIconDirectory, withIntermediateDirectories: true)

guard
    let sourceImage = NSImage(contentsOf: sourceURL),
    let sourceCGImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    throw NSError(domain: "IconInstall", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to read \(sourceURL.path)"])
}

let preparedImage = try removeEdgeBackground(from: sourceCGImage)
let trimmedRect = try detectTrimmedRect(in: preparedImage)
let roughlyTrimmedImage = try crop(preparedImage, to: trimmedRect)
let finalRect = try tightenVisibleBounds(in: roughlyTrimmedImage)
let trimmedImage = try crop(roughlyTrimmedImage, to: finalRect)
let maskedImage = try applyRoundedMask(to: trimmedImage)
let cleanedImage = try removeWhiteHalo(from: maskedImage)

try bitmap(from: cleanedImage).pngData().write(to: croppedPreviewURL)
print("wrote \(croppedPreviewURL.path)")
print("trimmed bounds: x=\(Int(trimmedRect.origin.x)) y=\(Int(trimmedRect.origin.y)) w=\(Int(trimmedRect.width)) h=\(Int(trimmedRect.height))")
print("final bounds inside trimmed image: x=\(Int(finalRect.origin.x)) y=\(Int(finalRect.origin.y)) w=\(Int(finalRect.width)) h=\(Int(finalRect.height))")

for spec in specs {
    let resized = try resize(cleanedImage, to: spec.size)
    let url = appIconDirectory.appendingPathComponent(spec.filename)
    try bitmap(from: resized).pngData().write(to: url)
    print("wrote \(url.path)")
}

func detectTrimmedRect(in image: CGImage) throws -> CGRect {
    guard let dataProvider = image.dataProvider, let data = dataProvider.data else {
        throw NSError(domain: "IconInstall", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to access image pixels"])
    }

    let width = image.width
    let height = image.height
    let bytesPerPixel = image.bitsPerPixel / 8
    let bytesPerRow = image.bytesPerRow
    let buffer = CFDataGetBytePtr(data)!

    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1

    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * bytesPerPixel
            let r = Int(buffer[offset])
            let g = Int(buffer[offset + 1])
            let b = Int(buffer[offset + 2])
            let a = bytesPerPixel >= 4 ? Int(buffer[offset + 3]) : 255

            if isContentPixel(r: r, g: g, b: b, a: a) {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard maxX >= minX, maxY >= minY else {
        throw NSError(domain: "IconInstall", code: 3, userInfo: [NSLocalizedDescriptionKey: "No non-white content detected in image"])
    }

    return CGRect(
        x: minX,
        y: minY,
        width: maxX - minX + 1,
        height: maxY - minY + 1
    ).integral
}

func isContentPixel(r: Int, g: Int, b: Int, a: Int) -> Bool {
    if a < 8 {
        return false
    }

    let whiteThreshold = 252
    if r >= whiteThreshold, g >= whiteThreshold, b >= whiteThreshold {
        return false
    }

    return true
}

func removeEdgeBackground(from image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let buffer = context.data
    else {
        throw NSError(domain: "IconInstall", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"])
    }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let pixels = buffer.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

    var visited = Array(repeating: false, count: width * height)
    var queue: [(Int, Int)] = []
    queue.reserveCapacity(width * 4 + height * 4)

    func enqueue(_ x: Int, _ y: Int) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let index = y * width + x
        guard !visited[index] else { return }
        visited[index] = true
        queue.append((x, y))
    }

    for x in 0..<width {
        enqueue(x, 0)
        enqueue(x, height - 1)
    }
    for y in 0..<height {
        enqueue(0, y)
        enqueue(width - 1, y)
    }

    var cursor = 0
    while cursor < queue.count {
        let (x, y) = queue[cursor]
        cursor += 1

        let offset = y * bytesPerRow + x * bytesPerPixel
        let r = Int(pixels[offset])
        let g = Int(pixels[offset + 1])
        let b = Int(pixels[offset + 2])
        let a = Int(pixels[offset + 3])

        guard isBackgroundPixel(r: r, g: g, b: b, a: a) else {
            continue
        }

        pixels[offset + 3] = 0

        enqueue(x - 1, y)
        enqueue(x + 1, y)
        enqueue(x, y - 1)
        enqueue(x, y + 1)
    }

    guard let output = context.makeImage() else {
        throw NSError(domain: "IconInstall", code: 9, userInfo: [NSLocalizedDescriptionKey: "Failed to render processed image"])
    }

    return output
}

func isBackgroundPixel(r: Int, g: Int, b: Int, a: Int) -> Bool {
    if a < 8 {
        return true
    }

    let threshold = 248
    return r >= threshold && g >= threshold && b >= threshold
}

func isLooseBackgroundPixel(r: Int, g: Int, b: Int, a: Int) -> Bool {
    if a < 8 {
        return true
    }

    let threshold = 242
    return r >= threshold && g >= threshold && b >= threshold
}

func crop(_ image: CGImage, to rect: CGRect) throws -> CGImage {
    let adjusted = CGRect(
        x: rect.origin.x,
        y: CGFloat(image.height) - rect.origin.y - rect.height,
        width: rect.width,
        height: rect.height
    ).integral

    guard let cropped = image.cropping(to: adjusted) else {
        throw NSError(domain: "IconInstall", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to crop image"])
    }

    return cropped
}

func tightenVisibleBounds(in image: CGImage) throws -> CGRect {
    guard let dataProvider = image.dataProvider, let data = dataProvider.data else {
        throw NSError(domain: "IconInstall", code: 10, userInfo: [NSLocalizedDescriptionKey: "Unable to access cropped pixels"])
    }

    let width = image.width
    let height = image.height
    let bytesPerPixel = image.bitsPerPixel / 8
    let bytesPerRow = image.bytesPerRow
    let buffer = CFDataGetBytePtr(data)!

    func backgroundRatioForColumn(_ x: Int, fromY: Int, toY: Int) -> Double {
        var background = 0
        for y in fromY..<toY {
            let offset = y * bytesPerRow + x * bytesPerPixel
            let r = Int(buffer[offset])
            let g = Int(buffer[offset + 1])
            let b = Int(buffer[offset + 2])
            let a = bytesPerPixel >= 4 ? Int(buffer[offset + 3]) : 255
            if isLooseBackgroundPixel(r: r, g: g, b: b, a: a) {
                background += 1
            }
        }
        return Double(background) / Double(max(1, toY - fromY))
    }

    func backgroundRatioForRow(_ y: Int, fromX: Int, toX: Int) -> Double {
        var background = 0
        for x in fromX..<toX {
            let offset = y * bytesPerRow + x * bytesPerPixel
            let r = Int(buffer[offset])
            let g = Int(buffer[offset + 1])
            let b = Int(buffer[offset + 2])
            let a = bytesPerPixel >= 4 ? Int(buffer[offset + 3]) : 255
            if isLooseBackgroundPixel(r: r, g: g, b: b, a: a) {
                background += 1
            }
        }
        return Double(background) / Double(max(1, toX - fromX))
    }

    var left = 0
    var right = width
    var top = 0
    var bottom = height

    while left + 8 < right, backgroundRatioForColumn(left, fromY: top, toY: bottom) > 0.92 {
        left += 1
    }
    while right - 8 > left, backgroundRatioForColumn(right - 1, fromY: top, toY: bottom) > 0.92 {
        right -= 1
    }
    while top + 8 < bottom, backgroundRatioForRow(top, fromX: left, toX: right) > 0.92 {
        top += 1
    }
    while bottom - 8 > top, backgroundRatioForRow(bottom - 1, fromX: left, toX: right) > 0.92 {
        bottom -= 1
    }

    let safetyInset = max(2, min(width, height) / 200)
    let adjustedLeft = min(left + safetyInset, right - 1)
    let adjustedRight = max(right - safetyInset, adjustedLeft + 1)
    let adjustedTop = min(top + safetyInset, bottom - 1)
    let adjustedBottom = max(bottom - safetyInset, adjustedTop + 1)

    return CGRect(
        x: adjustedLeft,
        y: adjustedTop,
        width: adjustedRight - adjustedLeft,
        height: adjustedBottom - adjustedTop
    ).integral
}

func applyRoundedMask(to image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        throw NSError(domain: "IconInstall", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to create mask context"])
    }

    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    let inset = CGFloat(max(8, min(width, height) / 90))
    let maskedRect = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = min(maskedRect.width, maskedRect.height) * 0.12
    context.addPath(CGPath(roundedRect: maskedRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    context.clip()
    context.draw(image, in: rect)

    guard let output = context.makeImage() else {
        throw NSError(domain: "IconInstall", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to render masked image"])
    }

    return output
}

func removeWhiteHalo(from image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let buffer = context.data
    else {
        throw NSError(domain: "IconInstall", code: 13, userInfo: [NSLocalizedDescriptionKey: "Failed to create halo-cleanup context"])
    }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let pixels = buffer.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * bytesPerPixel
            let r = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let b = Int(pixels[offset + 2])
            let a = Int(pixels[offset + 3])

            if a > 0, a < 255, r > 200, g > 200, b > 200 {
                pixels[offset + 3] = 0
            }
        }
    }

    guard let output = context.makeImage() else {
        throw NSError(domain: "IconInstall", code: 14, userInfo: [NSLocalizedDescriptionKey: "Failed to render halo-cleaned image"])
    }

    return output
}

func resize(_ image: CGImage, to size: Int) throws -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard
        let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        throw NSError(domain: "IconInstall", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create resize context"])
    }

    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

    guard let resized = context.makeImage() else {
        throw NSError(domain: "IconInstall", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to render resized image"])
    }

    return resized
}

func bitmap(from image: CGImage) -> NSBitmapImageRep {
    NSBitmapImageRep(cgImage: image)
}

extension NSBitmapImageRep {
    func pngData() throws -> Data {
        guard let data = representation(using: .png, properties: [:]) else {
            throw NSError(domain: "IconInstall", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
        }
        return data
    }
}
