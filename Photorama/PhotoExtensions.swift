//
//  PhotoExtensions.swift
//  Photorama
//
//  Created by Justin Storm on 4/6/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import Foundation

extension Photo {
    
    var isExpired: Bool {
        get {
            let cutoffDate = Date().addingTimeInterval(-3600 * 36) //anything older than 36 hours
            guard let upload = dateUploaded as Date? else {
                return true // no date uploaded, so i guess it's old
            }
            return upload < cutoffDate
        }
    }
    
}
