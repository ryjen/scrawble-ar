/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Core Graphics utility extensions used in the sample code.
 */

import UIKit
import CoreGraphics
import CoreMedia
import ImageIO

extension CGPoint {
    func scaled(byFactor: CGFloat) -> CGPoint {
        return CGPoint(x: self.x * byFactor, y: self.y * byFactor)
    }
}

extension CGSize {
    func scaled(byFactor: CGFloat) -> CGSize {
        return CGSize(width: width*byFactor, height: height*byFactor)
    }
    
    func scaleFactor(to size: CGSize, fit: Bool = true) -> CGFloat {
        let (widthFactor, heightFactor) = (size.width / self.width, size.height / self.height)
        let scaleFactor = fit ? min(widthFactor, heightFactor) : max(widthFactor, heightFactor)
        return scaleFactor
    }
}

extension CGImage {
    
    var extent: CGRect {
        get {
            return CGRect(x: 0, y: 0, width: self.width, height: self.height)
        }
    }
    
    func createMatchingBackingDataWithImage(orienation: UIImageOrientation) -> CGImage? {
        var orientedImage: CGImage?
    
        let originalWidth = self.width
        let originalHeight = self.height
        let bitsPerComponent = self.bitsPerComponent
        let bytesPerRow = self.bytesPerRow
        
        let colorSpace = self.colorSpace
        let bitmapInfo = self.bitmapInfo
        
        var degreesToRotate: Double
        var swapWidthHeight: Bool
        var mirrored: Bool
        switch orienation {
        case .up:
            degreesToRotate = 0.0
            swapWidthHeight = false
            mirrored = false
            break
        case .upMirrored:
            degreesToRotate = 0.0
            swapWidthHeight = false
            mirrored = true
            break
        case .right:
            degreesToRotate = 90.0
            swapWidthHeight = true
            mirrored = false
            break
        case .rightMirrored:
            degreesToRotate = 90.0
            swapWidthHeight = true
            mirrored = true
            break
        case .down:
            degreesToRotate = 180.0
            swapWidthHeight = false
            mirrored = false
            break
        case .downMirrored:
            degreesToRotate = 180.0
            swapWidthHeight = false
            mirrored = true
            break
        case .left:
            degreesToRotate = -90.0
            swapWidthHeight = true
            mirrored = false
            break
        case .leftMirrored:
            degreesToRotate = -90.0
            swapWidthHeight = true
            mirrored = true
            break
        }
        let radians = degreesToRotate * Double.pi / 180
        
        var width: Int
        var height: Int
        if swapWidthHeight {
            width = originalHeight
            height = originalWidth
        } else {
            width = originalWidth
            height = originalHeight
        }
        
        if let contextRef = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace!, bitmapInfo: bitmapInfo.rawValue) {
            
            contextRef.translateBy(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
            if mirrored {
                contextRef.scaleBy(x: -1.0, y: 1.0)
            }
            contextRef.rotate(by: CGFloat(radians))
            if swapWidthHeight {
                contextRef.translateBy(x: -CGFloat(height) / 2.0, y: -CGFloat(width) / 2.0)
            } else {
                contextRef.translateBy(x: -CGFloat(width) / 2.0, y: -CGFloat(height) / 2.0)
            }
            contextRef.draw(self, in: CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight))
            
            orientedImage = contextRef.makeImage()
        }
    
        return orientedImage
    }
}

extension CVPixelBuffer {
    func toCGImage() -> CGImage? {
        return toCGImage(in: extent)
    }
    
    var extent: CGRect {
        get {
            return CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(self), height: CVPixelBufferGetHeight(self))
        }
    }
    
    func toCGImage(in rect: CGRect) -> CGImage? {
        let ciimage = CIImage(cvPixelBuffer: self)
        
        let context = CIContext(options: nil)
        
        let cgimage = context.createCGImage(ciimage, from: rect)
        
        return cgimage
    }
    
    func toCGImage(in rect: CGRect, orientation: UIImageOrientation) -> CGImage? {

        let cgimage = toCGImage()
        
        return cgimage?.createMatchingBackingDataWithImage(orienation: orientation)?.cropping(to: rect)
    }
}

extension CGRect {
    
    func split() -> [CGRect] {
        var subs: [CGRect] = []
        
        let midX = (self.size.width/2) / self.size.width
        let midY = (self.size.height/2) / self.size.height
        
        var box = CGRect(x: 0, y: 0, width: midX, height: midY)
        
        subs.append(box)
        
        box = CGRect(x: midX, y: 0, width: midX, height: midY)
        
        subs.append(box)
        
        box = CGRect(x: 0, y: midY, width: midX, height: midY)
        
        subs.append(box)
        
        box = CGRect(x: midX, y: midY, width: midX, height: midY)
        
        subs.append(box)
        
        return subs;
    }
    
    
    func scaleAndCrop(to size: CGSize, fit: Bool = true) -> CGRect {
        
        // Calculate scale factor for fit or fill
        let scaleFactor = self.size.scaleFactor(to: size, fit: fit)
        
        // Establish drawing destination, which may start outside the drawing context bounds
        let scaledSize = self.size.scaled(byFactor: scaleFactor)
        
        let drawingOrigin = CGPoint(x: (size.width - scaledSize.width) / 2.0, y: (size.height - scaledSize.height) / 2.0)
        
        return CGRect(origin: drawingOrigin, size: scaledSize)
    }
    
    func scaleAndCrop(to rect: CGRect, fit: Bool = true) -> CGRect {
        
        // Calculate scale factor for fit or fill
        let scaleFactor = self.size.scaleFactor(to: rect.size, fit: fit)
        
        // Establish drawing destination, which may start outside the drawing context bounds
        let scaledSize = self.size.scaled(byFactor: scaleFactor)
        
        let scaledOrigin = self.origin.scaled(byFactor: scaleFactor)
        
        return CGRect(origin: scaledOrigin, size: scaledSize)
    }
    
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.size.width * size.width,
            height: self.size.height * size.height
        )
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImageOrientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }
}


