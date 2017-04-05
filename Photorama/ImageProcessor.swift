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
        case cancelled
    }
    
    enum Priority {
        case high, low
    }
 
    enum Result {
        case success(UIImage)
        case failure(Swift.Error)
        case cancelled
    }
    
    typealias ResultHandler = (Result) -> Void
    
    private let processingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 5
        return queue
    }()
    
    func process(image: UIImage, actions: [Action],
                 priority: ImageProcessor.Priority,
                 completion: @escaping ResultHandler) -> ImageProcessingRequest {
        let imageOp = ImageProcessingOperation(image: image, actions: actions,
                                               priority: priority,
                                               completion: completion)
        
        let request = ImageProcessingRequest(operation: imageOp, queue: processingQueue)
        processingQueue.addOperation(imageOp)
        return request
    }
}
