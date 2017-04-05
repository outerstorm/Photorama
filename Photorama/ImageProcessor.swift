//
//  ImageProcessor.swift
//  Photorama
//
//  Created by Justin Storm on 4/4/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import UIKit

class ImageProcessor {
    
    enum Action {
        case scale(maxSize: CGSize)
        case pixellatedFaces
        case filter(Filter)
    }
    
    enum Filter {
        case none
        case gloom(intensity: Double, radius: Double)
        case sephia(intensity: Double)
        case blur(radius: Double)
        case mono(color: UIColor, intensity: Double)
    }
    
    enum Error: Swift.Error {
        case incompatibleImage
        case filterConfiguration(name: String, params: [String:AnyObject]?)
    }
 
    func perform(_ actions: [Action], on image: UIImage) throws -> UIImage {
        // Set up the CIImage and context
        
        guard var workingImage = CIImage(image: image) else {
            throw Error.incompatibleImage
        }
        
        let context = CIContext(options: nil)
        
        // Apply requested processing
        try actions.forEach { action in
            switch action {
            case .pixellatedFaces:
                workingImage = workingImage.pixellatedFaces(using: context)
            case .scale(let maxSize):
                workingImage = workingImage.scaled(toFit: maxSize)
            case .filter(let filter):
                workingImage = try workingImage.filtered(filter)
            }
        }
        
        // Extract the result and handle it
        let rendereredImage = context.createCGImage(workingImage, from: workingImage.extent)!
        
        let resultImage = UIImage(cgImage: rendereredImage)
        return resultImage
    }
}
