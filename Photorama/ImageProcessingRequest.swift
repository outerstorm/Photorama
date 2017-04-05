//
//  ImageProcessingRequest.swift
//  Photorama
//
//  Created by Justin Storm on 4/5/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import UIKit

class ImageProcessingRequest {
    private var operation: ImageProcessingOperation
    private let queue: OperationQueue
    
    var priority: ImageProcessor.Priority = .low {
        didSet(oldPriority) {
            guard priority != oldPriority else { return }
            guard !operation.isExecuting else { return }
            
            let newOp = ImageProcessingOperation(operation: operation, priority: priority)
            operation.cancel()
            operation = newOp
            queue.addOperation(newOp)
        }
    }
    
    init(operation: ImageProcessingOperation, queue: OperationQueue) {
        self.operation = operation
        self.queue = queue
    }
    
    func cancel() {
        operation.cancel()
    }
}
