import UIKit
import CoreImage

/// Xaritadagi odam pin-iconchasini chizadi: doiraviy asosiy rasm + pastda ko'rsatkich uchburchak.
/// VIP bo'lmagan ko'ruvchi uchun rasm blur qilinadi (dashboard kartasi bilan bir xil uslub).
enum MapPinRenderer {
    static let diameter: CGFloat = 56

    private static let ciContext = CIContext()

    /// Rasm yuklanmaguncha ko'rsatiladigan vaqtinchalik icon.
    static func placeholder(isOnline: Bool) -> UIImage {
        let size = CGSize(width: diameter + 8, height: diameter + 18)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let circleRect = CGRect(x: 4, y: 4, width: diameter, height: diameter)
            drawShadowCircle(in: circleRect, cgContext: ctx.cgContext)

            UIColor.systemGray4.setFill()
            UIBezierPath(ovalIn: circleRect.insetBy(dx: 3, dy: 3)).fill()

            if let person = UIImage(systemName: "person.fill") {
                let tinted = person.withTintColor(.white, renderingMode: .alwaysOriginal)
                let iconSize: CGFloat = diameter * 0.45
                let iconRect = CGRect(
                    x: circleRect.midX - iconSize / 2,
                    y: circleRect.midY - iconSize / 2,
                    width: iconSize, height: iconSize
                )
                tinted.draw(in: iconRect)
            }

            drawPointer(size: size, circleMaxY: circleRect.maxY)
            if isOnline { drawOnlineDot(circleRect: circleRect) }
        }
    }

    /// Asosiy rasm bilan to'liq pin — `blurred: true` bo'lsa, VIP bo'lmagan ko'ruvchi uchun xira qilinadi.
    static func render(image: UIImage, blurred: Bool, isOnline: Bool, isVip: Bool) -> UIImage {
        let size = CGSize(width: diameter + 8, height: diameter + 18)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let circleRect = CGRect(x: 4, y: 4, width: diameter, height: diameter)
            drawShadowCircle(in: circleRect, cgContext: ctx.cgContext)

            let photoRect = circleRect.insetBy(dx: 3, dy: 3)
            ctx.cgContext.saveGState()
            UIBezierPath(ovalIn: photoRect).addClip()
            let toDraw = blurred ? (blur(image, radius: 8) ?? image) : image
            toDraw.drawAsAspectFill(in: photoRect)
            ctx.cgContext.restoreGState()

            // VIP olib qo'yilganda qulf belgisi
            if blurred, let lock = UIImage(systemName: "lock.fill") {
                let tinted = lock.withTintColor(.white, renderingMode: .alwaysOriginal)
                let s: CGFloat = diameter * 0.32
                tinted.draw(in: CGRect(x: circleRect.midX - s / 2, y: circleRect.midY - s / 2, width: s, height: s))
            }

            // VIP toj belgisi (premium foydalanuvchi pin'i)
            if isVip, let crown = UIImage(systemName: "crown.fill") {
                let tinted = crown.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
                let s: CGFloat = 16
                let badgeRect = CGRect(x: circleRect.minX - 2, y: circleRect.minY - 2, width: s, height: s)
                UIColor.white.setFill()
                UIBezierPath(ovalIn: badgeRect.insetBy(dx: -2, dy: -2)).fill()
                tinted.draw(in: badgeRect)
            }

            drawPointer(size: size, circleMaxY: circleRect.maxY)
            if isOnline { drawOnlineDot(circleRect: circleRect) }
        }
    }

    // MARK: - Helpers

    private static func drawShadowCircle(in rect: CGRect, cgContext: CGContext) {
        cgContext.saveGState()
        cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 5,
                             color: UIColor.black.withAlphaComponent(0.3).cgColor)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: rect).fill()
        cgContext.restoreGState()
    }

    private static func drawPointer(size: CGSize, circleMaxY: CGFloat) {
        let midX = size.width / 2
        let path = UIBezierPath()
        path.move(to: CGPoint(x: midX - 7, y: circleMaxY - 3))
        path.addLine(to: CGPoint(x: midX + 7, y: circleMaxY - 3))
        path.addLine(to: CGPoint(x: midX, y: circleMaxY + 11))
        path.close()
        UIColor.white.setFill()
        path.fill()
    }

    private static func drawOnlineDot(circleRect: CGRect) {
        let outer = CGRect(x: circleRect.maxX - 16, y: circleRect.minY - 2, width: 16, height: 16)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: outer).fill()
        UIColor.systemGreen.setFill()
        UIBezierPath(ovalIn: outer.insetBy(dx: 2, dy: 2)).fill()
    }

    private static func blur(_ image: UIImage, radius: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage else { return nil }
        guard let cgImage = ciContext.createCGImage(output, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private extension UIImage {
    /// `scaledToFill` uslubida (aspect-fill) chizadi — UIKit'da kesib chizish.
    func drawAsAspectFill(in rect: CGRect) {
        let imgSize = self.size
        guard imgSize.width > 0, imgSize.height > 0 else { draw(in: rect); return }
        let scale = max(rect.width / imgSize.width, rect.height / imgSize.height)
        let scaledW = imgSize.width * scale
        let scaledH = imgSize.height * scale
        let x = rect.midX - scaledW / 2
        let y = rect.midY - scaledH / 2
        draw(in: CGRect(x: x, y: y, width: scaledW, height: scaledH))
    }
}
