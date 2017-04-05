//
//  ImageProcessingOperation.swift
//  Photorama
//
//  Created by Justin Storm on 4/5/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import UIKit

class ImageProcessingOperation: Operation {
    var image: UIImage?
    let actions: [ImageProcessor.Action]
    let completion: ImageProcessor.ResultHandler
    
    init(image: UIImage, actions: [ImageProcessor.Action],
         priority: ImageProcessor.Priority,
         completion: @escaping ImageProcessor.ResultHandler) {
        self.image = image
        self.actions = actions
        self.completion = completion
        
        super.init()
        
        switch priority {
        case .high:
            qualityOfService = .userInitiated
            queuePriority = .high
        case .low:
            qualityOfService = .utility
            queuePriority = .low
        }
    }
    
    convenience init(operation: ImageProcessingOperation, priority: ImageProcessor.Priority = .low) {
        guard let image = operation.image else {
            preconditionFailure("FATAL:  Attempt to clone an operation with nil image.")
        }
        
        self.init(image: image, actions: operation.actions, priority: priority, completion: operation.completion)
    }

    override func cancel() {
        super.cancel()
        image = nil
    }
    
    override func main() {
        guard let image = image else {
            completion(.cancelled)
            return
        }
        
        do {
            let processedImage = try perform(actions, on: image)
            completion(.success(processedImage))
        } catch {
            completion(.failure(error))
        }
    }
    
    func perform(_ actions: [ImageProcessor.Action], on image: UIImage) throws -> UIImage {
        // Set up the CIImage and context
        
        guard !isCancelled else { throw ImageProcessor.Error.cancelled }
        
        guard var workingImage = CIImage(image: image) else {
            throw ImageProcessor.Error.incompatibleImage
        }
        
        let context = CIContext(options: nil)
        
        // Apply requested processing
        try actions.forEach { action in
            
            guard !isCancelled else { throw ImageProcessor.Error.cancelled }
            
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
        
        guard !isCancelled else { throw ImageProcessor.Error.cancelled }
        
        return resultImage
    }

}
