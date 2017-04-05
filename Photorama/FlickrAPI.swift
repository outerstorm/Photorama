//
//  FlickrAPI.swift
//  Photorama
//
//  Created by Justin Storm on 3/29/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import Foundation
import CoreData

enum FlickrError: Error {
    case invalidJSONData
}

enum FeedType: Int32 {
    case interesting = 1
    case recent = 2
}

enum Method: String {
    case interestingPhotos = "flickr.interestingness.getList"
    case recentPhotos = "flickr.photos.getRecent"
}

struct FlickrAPI {
    private static let baseURLString = "https://api.flickr.com/services/rest"
    private static let apiKey = "a6d819499131071f158fd740860a5a88"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static var interestingPhotosURL: URL? {
        return flickrURL(method: .interestingPhotos, parameters: ["extras": "url_h,date_taken,date_upload"])
    }
    
    static var recentPhotosURL: URL? {
        return flickrURL(method: .recentPhotos, parameters: ["extras": "url_h,date_taken,date_upload"])
    }

    private static func flickrURL(method: Method, parameters: [String: String]?) -> URL? {
        var components = URLComponents(string: baseURLString)
        var queryItems = [URLQueryItem]()

        let baseParams = [
            "method": method.rawValue,
            "format": "json",
            "nojsoncallback": "1",
            "api_key": apiKey,
            "safe_search": "1"
        ]
        queryItems = baseParams.map( { return URLQueryItem(name: $0.key, value: $0.value) })

        if let additionalParams = parameters {
            let additionalItems = additionalParams.map( { return URLQueryItem(name: $0.key, value: $0.value) })
            queryItems.append(contentsOf: additionalItems)
        }

        components?.queryItems = queryItems
        return components?.url
    }

    static func photos(fromJSON data: Data, andFeedType feedType: FeedType, into context: NSManagedObjectContext) -> PhotosResult {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data,
                                                              options: [])
            guard
                let jsonDictionary = jsonObject as? [AnyHashable: Any],
                let photos = jsonDictionary["photos"] as? [String: Any],
                let photosArray = photos["photo"] as? [[String: Any]] else {
                    
                    return .failure(FlickrError.invalidJSONData)
            }
            
            var finalPhotos = [Photo]()
            for photoJSON in photosArray {
                if let photo = photo(fromJSON: photoJSON, andFeedType: feedType, into: context) {
                    finalPhotos.append(photo)
                }
            }
            if finalPhotos.isEmpty && !photosArray.isEmpty {
                // We weren't able to parse any of the photos
                // Maybe the JSON format for photos has changed
                return .failure(FlickrError.invalidJSONData)
            }
            
            return .success(finalPhotos)
        } catch let error {
            return .failure(error)
        }
    }

    static func photo(fromJSON json: [String: Any], andFeedType feedType: FeedType, into context: NSManagedObjectContext) -> Photo? {
        guard let photoID = json["id"] as? String else {
            return nil
        }
        guard let title = json["title"] as? String else {
            return nil
        }
        guard let dateString = json["datetaken"] as? String else {
            return nil
        }
        guard let photoURLString = json["url_h"] as? String else {
            return nil
        }
        guard let url = URL(string: photoURLString) else {
            return nil
        }
        guard let dateTaken = dateFormatter.date(from: dateString) else {
            return nil
        }
        guard let dateUploadedStr = json["dateupload"] as? String else {
            return nil
        }
        
        var dateUploaded: Date = Date()
        guard let epoch = Double(dateUploadedStr) else {
            return nil
        }
        dateUploaded = Date(timeIntervalSince1970: epoch)
        
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "\(#keyPath(Photo.photoID)) == \(photoID)")
        fetchRequest.predicate = predicate
        var fetchedPhotos: [Photo]?
        context.performAndWait {
            fetchedPhotos = try? fetchRequest.execute()
        }
        if let existingPhoto = fetchedPhotos?.first {
            return existingPhoto
        }
        
        var photo: Photo!
        context.performAndWait {
            photo = Photo(context: context)
            photo.title = title
            photo.photoID = photoID
            photo.remoteURL = url as NSURL
            photo.dateUploaded = dateUploaded as NSDate
            photo.dateTaken = dateTaken as NSDate
            photo.feedType = feedType.rawValue
        }
        
        return photo
    }

}
