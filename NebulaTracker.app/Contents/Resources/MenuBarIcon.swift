import Cocoa

extension NSImage {
    static func nebulaLogo(size: CGSize = CGSize(width: 18, height: 18)) -> NSImage? {
        // Option 1: Load from file
        // If you have a logo file, place it in Resources/nebula-logo.png
        if let logoPath = Bundle.main.path(forResource: "nebula-logo", ofType: "png"),
           let image = NSImage(contentsOfFile: logoPath) {
            image.size = size
            return image
        }

        // Option 2: Create programmatically (a simple nebula-like design)
        let image = NSImage(size: size, flipped: false) { rect in
            // Create a gradient nebula effect
            let gradient = NSGradient(colors: [
                NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1.0),  // Purple
                NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0),  // Blue
                NSColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1.0)   // Light purple
            ])

            // Draw circular nebula
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            gradient?.draw(in: path, angle: 45)

            // Add some "stars" (dots)
            NSColor.white.setFill()
            let star1 = NSBezierPath(ovalIn: NSRect(x: 6, y: 6, width: 2, height: 2))
            let star2 = NSBezierPath(ovalIn: NSRect(x: 10, y: 10, width: 1.5, height: 1.5))
            let star3 = NSBezierPath(ovalIn: NSRect(x: 12, y: 5, width: 1, height: 1))
            star1.fill()
            star2.fill()
            star3.fill()

            return true
        }

        image.isTemplate = false  // Keep colors
        return image
    }

    static func nebulaLogoTemplate(size: CGSize = CGSize(width: 18, height: 18)) -> NSImage? {
        // Template version (monochrome) that adapts to menu bar theme
        let image = NSImage(size: size, flipped: false) { rect in
            // Draw a simple spiral galaxy shape
            NSColor.black.setFill()

            // Center circle
            let center = NSBezierPath(ovalIn: NSRect(x: 7, y: 7, width: 4, height: 4))
            center.fill()

            // Spiral arms (simplified)
            let arm1 = NSBezierPath()
            arm1.move(to: NSPoint(x: 9, y: 9))
            arm1.curve(to: NSPoint(x: 14, y: 12),
                      controlPoint1: NSPoint(x: 11, y: 8),
                      controlPoint2: NSPoint(x: 13, y: 10))
            arm1.lineWidth = 1.5
            arm1.stroke()

            let arm2 = NSBezierPath()
            arm2.move(to: NSPoint(x: 9, y: 9))
            arm2.curve(to: NSPoint(x: 4, y: 6),
                      controlPoint1: NSPoint(x: 7, y: 10),
                      controlPoint2: NSPoint(x: 5, y: 8))
            arm2.lineWidth = 1.5
            arm2.stroke()

            // Add dots for stars
            let star1 = NSBezierPath(ovalIn: NSRect(x: 3, y: 12, width: 1.5, height: 1.5))
            let star2 = NSBezierPath(ovalIn: NSRect(x: 14, y: 4, width: 1.5, height: 1.5))
            let star3 = NSBezierPath(ovalIn: NSRect(x: 12, y: 14, width: 1, height: 1))
            star1.fill()
            star2.fill()
            star3.fill()

            return true
        }

        image.isTemplate = true  // This makes it adapt to dark/light mode
        return image
    }
}

// Instructions for using a custom logo file:
// 1. Add your logo as "nebula-logo.png" or "nebula-logo.svg" to the Resources folder
// 2. For best results, use a 36x36px image (18x18 @2x for Retina)
// 3. For menu bar icons, use either:
//    - A black icon with transparent background (will auto-adapt to dark/light mode)
//    - A full-color icon that looks good on both dark and light backgrounds