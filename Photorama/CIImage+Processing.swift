//
//  CIImage+Processing.swift
//  Photorama
//
//  Created by Justin Storm on 4/4/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import CoreImage

extension CIImage {
    func scaled(toFit maxSize: CGSize) -> CIImage {
        let aspectRatio = extent.width / extent.height
        let scale: CGFloat
        
        if aspectRatio > 1.0 {
            scale = maxSize.width / extent.width
        } else {
            scale = maxSize.height / extent.height
        }
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        
        let outputImage = applying(scaleTransform)
        return outputImage
    }
    
    func pixellatedFaces(using context: CIContext) -> CIImage {
        guard let features = faceFeatures(using: context), !features.isEmpty else {
            return self
        }
        
        let resultImage = features.reduce(self) { inputImage, face in
            let faceImage = self.cropping(to: face.bounds)
            let pixellatedFaceImage = faceImage.pixellated()
            let compositedFaceImage = pixellatedFaceImage.compositingOverImage(inputImage)
            return compositedFaceImage
        }
        
        return resultImage
    }
    
    func pixellated() -> CIImage {
        let inputParams: [String:AnyObject] = [
            kCIInputImageKey: self,
            kCIInputScaleKey: NSNumber(value: 45.0),
            kCIInputCenterKey: CIVector(x: 0, y: 0)
        ]
        
        guard let filter = CIFilter(name: "CIPixellate", withInputParameters: inputParams),
            let output = filter.outputImage else {
            
            fatalError("CIImage.pixellated() failed to configure its filter.")
        }
        
        return output
    }
    
    func filtered(_ filter: ImageProcessor.Filter) throws -> CIImage {
        let parameters: [String: AnyObject]
        let filterName: String
        let shouldCrop: Bool
        
        // Configure the CIFilter() inputs based on the chosen filter
        switch filter {
        case .none:
            return self
        case .gloom(let intensity, let radius):
            parameters = [
                kCIInputImageKey: self,
                kCIInputIntensityKey: NSNumber(value: intensity),
                kCIInputRadiusKey: NSNumber(value: radius)
            ]
            filterName = "CIGloom"
            shouldCrop = true
        case .sephia(let intensity):
            parameters = [
                kCIInputImageKey: self,
                kCIInputIntensityKey: NSNumber(value: intensity)
            ]
            filterName = "CISepiaTone"
            shouldCrop = false
        case .blur(let radius):
            parameters = [
                kCIInputImageKey: self,
                kCIInputRadiusKey: NSNumber(value: radius)
            ]
            filterName = "CIGaussianBlur"
            shouldCrop = true
        }
        
        guard let filter = CIFilter(name: filterName, withInputParameters: parameters),
            let output = filter.outputImage else {
                
            throw ImageProcessor.Error.filterConfiguration(name: filterName, params: parameters)
        }
        
        return shouldCrop ? output.cropping(to: extent) : output
    }
    
    func faceFeatures(using context: CIContext) -> [CIFaceFeature]? {
        let detectorOptions = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: context, options: detectorOptions)
        
        let features = faceDetector?.features(in: self) as? [CIFaceFeature]
        
        return features
    }
}
