//
//  FlipLayout.swift
//  Photorama
//
//  Created by Justin Storm on 4/6/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import UIKit

class FlipLayout: UICollectionViewLayout {
    
    // MARK:  State and Metrics
    private var cellAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var cellSize: CGSize = CGSize.zero
    private var cellCenter: CGPoint = CGPoint.zero
    
    private var cellCount: Int {
        guard let collectionView = collectionView,
              let dataSource = collectionView.dataSource else {
            return 0
        }
        return dataSource.collectionView(collectionView, numberOfItemsInSection: 0)
    }
    
    private var currentOffset: CGFloat {
        guard let collectionView = collectionView else {
            return 0
        }
        return collectionView.contentOffset.y + collectionView.contentInset.top
    }
    
    private var currentCellIndex: Int {
        return max(0, Int(currentOffset / cellSize.height))
    }
    
    private var layoutRect: CGRect {
        guard let collectionView = collectionView else {
            return CGRect.zero
        }
        var rect = CGRect(origin: CGPoint.zero, size: collectionView.frame.size)
        rect = UIEdgeInsetsInsetRect(rect, collectionView.contentInset)
        return rect
    }
    
    private var shouldLayoutFromScratch: Bool = true
    
    override func prepare() {
        // Skip the layout preparation if the non-variable attributes are still valid
        guard shouldLayoutFromScratch else {
            return
        }
        
        cellSize = CGSize(width: layoutRect.width, height: layoutRect.height / 2.0)
        cellCenter = CGPoint(x: layoutRect.width / 2.0, y: layoutRect.height / 2.0)
        
        cellAttributes = [:]
        for cellIndex in 0 ..< cellCount {
            let indexPath = IndexPath(item: cellIndex, section: 0)
            let attributes = AnchorableAttributes(forCellWith: indexPath)
            attributes.size = cellSize
            attributes.center = cellCenter
            attributes.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            cellAttributes[indexPath] = attributes
        }
        
        shouldLayoutFromScratch = false
    }
    
    override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds)
        
        if newBounds.size != collectionView?.bounds.size {
            shouldLayoutFromScratch = true
        }
        
        var indexPaths: [IndexPath] = []
        let index = currentCellIndex
        indexPaths.append(IndexPath(item: index, section: 0))
        if index > 0 {
            indexPaths.append(IndexPath(item: index-1, section: 0))
        }
        
        if index < cellCount-1 {
            indexPaths.append(IndexPath(item: index+1, section: 0))
        }
        
        context.invalidateItems(at: indexPaths)
        return context
    }
    
    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        if context.invalidateEverything || context.invalidateDataSourceCounts {
            shouldLayoutFromScratch = true
        }
        super.invalidateLayout(with: context)
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override var collectionViewContentSize: CGSize {
        let contentWidth = layoutRect.width
        let contentHeight = (CGFloat(cellCount) * cellSize.height) + cellSize.height
        let contentSize = CGSize(width: contentWidth, height: contentHeight)
        return contentSize
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        updateAttributesForItem(at: indexPath)
        let attributes = cellAttributes[indexPath]
        return attributes
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var allAttributes: [UICollectionViewLayoutAttributes] = []
        for cellIndex in 0 ..< cellCount {
            let indexPath = IndexPath(item: cellIndex, section: 0)
            if let attributes = layoutAttributesForItem(at: indexPath) {
                allAttributes.append(attributes)
            }
        }
        return allAttributes
    }
    
    private func updateAttributesForItem(at indexPath: IndexPath) {
        guard let attributes = cellAttributes[indexPath] else {
            return
        }
        
        switch indexPath.item {
        case currentCellIndex:
            let relativeOffset = currentOffset / cellSize.height
            // fraction complete is the fractional progress from one cell to the next
            let fractionComplete = max(0, modf(relativeOffset).1)
            attributes.transform3D = transform3DForFlipCompletion(fractionComplete)
            attributes.zIndex = 1
            attributes.isHidden = false
        case currentCellIndex + 1:
            attributes.transform3D = transform3DForFlipCompletion(0.0)
            attributes.zIndex = 0
            attributes.isHidden = true
        case currentCellIndex - 1:
            attributes.transform3D = transform3DForFlipCompletion(1.0)
            attributes.zIndex = 0
            attributes.isHidden = true
        default:
            attributes.transform3D = transform3DForFlipCompletion(0.0)
            attributes.zIndex = 0
            attributes.isHidden = true
        }
    }
    
    private func transform3DForFlipCompletion(_ fractionComplete: CGFloat) -> CATransform3D {
        var transform = CATransform3DIdentity
        
        // Translate by the current offset so that the cell remains centered relative to
        // the screen even as the content area scrolls
        transform = CATransform3DTranslate(transform, 0.0, currentOffset, 0.0)
        
        // rotate vertically abou the X axis to flip the cell
        let rotation = CGFloat.pi * fractionComplete
        transform = CATransform3DRotate(transform, rotation, 1, 0, 0)
        
        return transform
    }
    
}
