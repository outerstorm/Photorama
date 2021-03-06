//
//  Photo+CoreDataProperties.swift
//  Photorama
//
//  Created by Justin Storm on 4/5/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var dateTaken: NSDate?
    @NSManaged public var dateUploaded: NSDate?
    @NSManaged public var photoID: String?
    @NSManaged public var remoteURL: NSObject?
    @NSManaged public var title: String?
    @NSManaged public var feedType: Int32
    @NSManaged public var tags: NSSet?

}

// MARK: Generated accessors for tags
extension Photo {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}
