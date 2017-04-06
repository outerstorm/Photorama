//
//  SpaceFillingFlowLayout.swift
//  Photorama
//
//  Created by Justin Storm on 4/6/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import UIKit

class SpaceFillingFlowLayout : UICollectionViewFlowLayout {
    
    @IBInspectable var minCellSize: CGSize = CGSize(width: 140, height: 140) {
        didSet {
            invalidateLayout()
        }
    }
    @IBInspectable var cellSpacing: CGFloat = 8 {
        didSet {
            invalidateLayout()
        }
    }
    
    private var cellCount: Int {
        guard let collectionView = collectionView,
            let dataSource = collectionView.dataSource else {
            return 0
        }
        return dataSource.collectionView(collectionView, numberOfItemsInSection: 0 )
    }
    
    private var contentSize: CGSize = CGSize.zero
    private var columns: Int = 0
    private var rows: Int = 0
    private var cellSize: CGSize = CGSize.zero
    private var cellCenterPoints: [CGPoint] = []
    
    override func prepare() {
        guard let collectionViewWidth = collectionView?.frame.size.width else {
            return
        }
        
        // Calculate the number of rows and columns
        columns = Int( (collectionViewWidth - cellSpacing) / (minCellSize.width + cellSpacing) )
        rows = Int ( ceil(Double(cellCount) / Double(columns)) )
        
        // Take the remaining gap and divide it among the existing columns
        let innerWidth = (CGFloat(columns) * (minCellSize.width + cellSpacing)) + cellSpacing
        let extraWidth = collectionViewWidth - innerWidth
        let cellGrowth = extraWidth/CGFloat(columns)
        
        cellSize.width = floor(minCellSize.width + cellGrowth)
        cellSize.height = cellSize.width
        
        // For each cell, calculate and store it's center point
        for itemIndex in 0 ..< cellCount {
            // Locate the cell's position in the grid
            let coordBreakdown = modf(CGFloat(itemIndex) / CGFloat(columns))
            let row = Int(coordBreakdown.0) + 1
            let col = Int(round(coordBreakdown.1 * CGFloat(columns))) + 1
            
            //Calculate the actual centerpoint of the cell given it's position
            var cellBottomRight = CGPoint.zero
            cellBottomRight.x = CGFloat(col) * (cellSpacing+cellSize.width)
            cellBottomRight.y = CGFloat(row) * (cellSpacing+cellSize.height)
            
            var cellCenter = CGPoint.zero
            cellCenter.x = cellBottomRight.x - (cellSize.width / 2.0)
            cellCenter.y = cellBottomRight.y - (cellSize.height / 2.0)
            
            cellCenterPoints.append(cellCenter)
        }
    }
    
    override var collectionViewContentSize: CGSize {
        let contentWidth = (cellSize.width + cellSpacing) * CGFloat(columns) + cellSpacing
        let contentHeight = (cellSize.height + cellSpacing) * CGFloat(rows) + cellSpacing
        let contentSize = CGSize(width: contentWidth, height: contentHeight)
        return contentSize
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var allAttributes: [UICollectionViewLayoutAttributes] = []
        
        for itemIndex in 0 ..< cellCount {
            if cellCenterPoints.count > itemIndex && rect.contains(cellCenterPoints[itemIndex]) {
                let indexPath = IndexPath(item: itemIndex, section: 0)
                if let attributes = layoutAttributesForItem(at: indexPath) {
                    allAttributes.append(attributes)
                }
            }
        }
        
        return allAttributes
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForItem(at: indexPath) else {
            return nil
        }
        
        attributes.size = cellSize
        attributes.center = cellCenterPoints[indexPath.row]
        
        return attributes
    }
}
