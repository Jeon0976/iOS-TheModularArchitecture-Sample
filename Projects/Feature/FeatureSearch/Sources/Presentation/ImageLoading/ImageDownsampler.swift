//
//  ImageDownsampler.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/15/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import ImageIO
import UIKit

enum ImageDownsampler {
    static func makeImage(
        from data: Data,
        pointSize: CGSize,
        scale: CGFloat
    ) async -> sending UIImage? {
        let maxPixel = max(pointSize.width, pointSize.height) * scale
        
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
