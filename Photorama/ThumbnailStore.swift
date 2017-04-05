//
//  ThumbnailStore.swift
//  Photorama
//
//  Created by Justin Storm on 4/5/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import UIKit

class ThumbnailStore {
    private let thumbnailCache = NSCache<NSString,UIImage>()
    
    func thumbnail(forKey key: NSString) -> UIImage? {
        return thumbnailCache.object(forKey: key)
    }
    
    func setThumbnail(image: UIImage, forKey key: NSString) {
        thumbnailCache.setObject(image, forKey: key)
    }
    
    func clearThumbnails() {
        thumbnailCache.removeAllObjects()
    }
}
