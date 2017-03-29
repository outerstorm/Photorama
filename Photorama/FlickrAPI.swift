//
//  FlickrAPI.swift
//  Photorama
//
//  Created by Justin Storm on 3/29/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import Foundation

enum FlickrError: Error {
    case invalidJSONData
}

enum Method: String {
    case interestingPhotos = "flickr.interestingness.getList"
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
        return flickrURL(method: .interestingPhotos, parameters: ["extras": "url_h,date_taken"])
    }

    private static func flickrURL(method: Method, parameters: [String: String]?) -> URL? {
        var components = URLComponents(string: baseURLString)
        var queryItems = [URLQueryItem]()

        let baseParams = [
            "method": method.rawValue,
            "format": "json",
            "nojsoncallback": "1",
            "api_key": apiKey
        ]
        queryItems = baseParams.map( { return URLQueryItem(name: $0.key, value: $0.value) })

        if let additionalParams = parameters {
            let additionalItems = additionalParams.map( { return URLQueryItem(name: $0.key, value: $0.value) })
            queryItems.append(contentsOf: additionalItems)
        }

        components?.queryItems = queryItems
        return components?.url
    }

    static func photos(fromJSON data: Data) -> PhotosResult {
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
                if let photo = photo(fromJSON: photoJSON) {
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

    static func photo(fromJSON json: [String: Any]) -> Photo? {
        guard
            let photoID = json["id"] as? String,
            let title = json["title"] as? String,
            let dateString = json["datetaken"] as? String,
            let photoURLString = json["url_h"] as? String,
            let url = URL(string: photoURLString),
            let dateTaken = dateFormatter.date(from: dateString) else {
                // Don't have enough information to construct a Photo
                return nil }
        return Photo(title: title, photoID: photoID, remoteURL: url, dateTaken: dateTaken)
    }

}