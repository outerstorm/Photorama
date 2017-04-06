//
//  AnchorableAttributes.swift
//  Photorama
//
//  Created by Justin Storm on 4/6/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import UIKit

class AnchorableAttributes: UICollectionViewLayoutAttributes {
    var anchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let theCopy = super.copy(with: zone) as! AnchorableAttributes
        theCopy.anchorPoint = anchorPoint

        return theCopy
    }
}
