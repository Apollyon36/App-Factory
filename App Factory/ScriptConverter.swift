import Foundation
import AVFoundation

class ScriptConverter {
    var scriptPath: NSURL
    var savePath: NSURL
    var iconPath: NSURL!
    var fullAppPath: NSURL
    var resourcesPath: NSURL
    var iconFileName: String!
    
    required init?(scriptPath: NSURL, savePath: NSURL, iconPath: NSURL!) {
        self.scriptPath = scriptPath
        self.savePath = savePath
        
        self.fullAppPath = savePath.URLByAppendingPathComponent("Contents/MacOs/")
        self.resourcesPath = savePath.URLByAppendingPathComponent("Contents/Resources/")
        
        if iconPath != nil {
            self.iconPath = iconPath
            self.iconFileName = "\(iconPath.URLByDeletingPathExtension!.lastPathComponent!).icns"
        }
    }
    
    func createApp() throws {
        try writeScript()
        
        if iconPath != nil {
            try writeIcon()
            try writePlist()
        }
    }
    
    func writeScript() throws {
        try makeScriptExecutable()
        
        let manager     = NSFileManager.defaultManager()
        let appFileName = self.scriptPath.URLByDeletingPathExtension!.lastPathComponent
        let fullPath    = self.fullAppPath.URLByAppendingPathComponent(appFileName!)
        
        try manager.createDirectoryAtURL(fullAppPath, withIntermediateDirectories: true, attributes: nil)
        try manager.copyItemAtURL(self.scriptPath, toURL: fullPath)
    }
    
    func makeScriptExecutable() throws {
        let manager    = NSFileManager.defaultManager()
        let scriptPath = self.scriptPath.path!
        var attributes = try manager.attributesOfItemAtPath(scriptPath)
        
        let existing = UInt16(attributes[NSFilePosixPermissions]!.shortValue)
        attributes[NSFilePosixPermissions] = Int(existing | S_IXUSR)
        try manager.setAttributes(attributes, ofItemAtPath: scriptPath)
    }
    
    func writeIcon() throws {
        let manager = NSFileManager.defaultManager()
        
        try manager.createDirectoryAtURL(self.resourcesPath, withIntermediateDirectories: true, attributes: nil)
        
        var img  = NSImage(contentsOfURL: self.iconPath)!.CGImageForProposedRect(nil, context: nil, hints: nil)!
        
        if (!imageHasCorrectSize(img)) {
            img = scaleImage(img, width: 256, height: 256)
        }
        
        let destPath = self.resourcesPath.URLByAppendingPathComponent(self.iconFileName)
        let dest     = CGImageDestinationCreateWithURL(destPath, kUTTypeAppleICNS, 0, nil)!
        
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }
    
    func scaleImage(image: CGImage, width: Int, height: Int) -> CGImage {
        let bitsPerComponent = CGImageGetBitsPerComponent(image)
        let bytesPerRow      = CGImageGetBytesPerRow(image)
        let colorSpace       = CGImageGetColorSpace(image)
        let bitmapInfo       = CGImageAlphaInfo.NoneSkipLast
        let bytesPerPixel    = bytesPerRow / CGImageGetWidth(image);
        let destBytesPerRow  = bytesPerPixel * width;
        let context          = CGBitmapContextCreate(nil, width, height, bitsPerComponent, destBytesPerRow, colorSpace, bitmapInfo.rawValue)
        
        CGContextSetInterpolationQuality(context, CGInterpolationQuality.High)
        CGContextDrawImage(context, CGRect(origin: CGPointZero, size: CGSize(width: CGFloat(width), height: CGFloat(height))), image)
        return CGBitmapContextCreateImage(context)!
    }
    
    func imageHasCorrectSize(image: CGImage) -> Bool {
        let allowedSizes = [16, 32, 48, 128, 256, 512, 1024]
        
        let height = CGImageGetHeight(image)
        let width  = CGImageGetWidth(image)
        
        return allowedSizes.contains(height) && height == width
    }
    
    func writePlist() throws {
        let iconStringPath = NSString(string: self.iconFileName).stringByDeletingPathExtension
        
        let content =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
            "<plist version=\"1.0\">\n" +
            "\t<dict>\n" +
            "\t\t<key>CFBundleIconFile</key>\n" +
            "\t\t<string>\(iconStringPath)</string>\n" +
            "\t</dict>\n" +
            "</plist>"
        
        let plistPath = savePath.URLByAppendingPathComponent("Contents/info.plist")

        try content.writeToURL(plistPath, atomically: true, encoding: NSUnicodeStringEncoding)
    }

}
