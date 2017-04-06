//
//  PhotoStore.swift
//  Photorama
//
//  Created by Justin Storm on 3/29/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import Foundation
import UIKit
import CoreData

enum ImageResult {
    case success(UIImage)
    case failure(Error)
}

enum PhotosResult {
    case success([Photo])
    case failure(Error)
}

enum TagsResult {
    case success([Tag])
    case failure(Error)
}

enum PhotoError: Error {
    case imageCreationError
}

class PhotoStore {
    
    let imageStore = ImageStore()

    let recentPhotosContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "PhotoramaRecent")
        container.loadPersistentStores { (description, error) in
            if let error = error {
                print("Error setting up Core Data (\(error)).")
            }
        }
        return container
    }()
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config)
    }()
    
    func fetchInterestingPhotos(completion: @escaping (PhotosResult) -> Void) {
        guard let url = FlickrAPI.interestingPhotosURL else {
            return
        }
        
        let request = URLRequest(url: url)
        let task = session.dataTask(with: request) { data, response, error -> Void in

            self.processPhotoRequest(feedType: .interesting, data: data, error: error, withContainer: self.recentPhotosContainer) { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
        task.resume()
    }
    
    func fetchRecentPhotos(completion: @escaping (PhotosResult) -> Void) {
        guard let url = FlickrAPI.recentPhotosURL else {
            return
        }
        
        let request = URLRequest(url: url)
        let task = session.dataTask(with: request) { data, response, error -> Void in
            
            self.processPhotoRequest(feedType: .recent, data: data, error: error, withContainer: self.recentPhotosContainer) { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
        task.resume()
    }
    

    func fetchImage(for photo: Photo, completion: @escaping (ImageResult) -> Void) {
        guard let photoKey = photo.photoID else {
            preconditionFailure("Photo expected to have a photoID.")
        }
        
        if let image = imageStore.imageForKey(key: photoKey) {
            DispatchQueue.main.async {
                completion(.success(image))
            }
        }
        
        guard let photoURL = photo.remoteURL as? URL else {
            preconditionFailure("Photo expected to have a remote URL.")
        }
        let request = URLRequest(url: photoURL)
        let task = session.dataTask(with: request) {
            (data, response, error) -> Void in
            
            let result = self.processImageRequest(data: data, error: error)
            
            if case let .success(image) = result {
                self.imageStore.setImage(image: image, forKey: photoKey)
            }
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
        task.resume()
    }
    
    static func photos(fromJSON data: Data, andFeedType feedType: FeedType, into context: NSManagedObjectContext) -> PhotosResult {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data,
                                                              options: [])
            guard
                let jsonDictionary = jsonObject as? [AnyHashable:Any],
                let photos = jsonDictionary["photos"] as? [String:Any],
                let photosArray = photos["photo"] as? [[String:Any]] else {
                    
                    return .failure(FlickrError.invalidJSONData)
            }
            var finalPhotos = [Photo]()
            for photoJSON in photosArray {
                if let photo = FlickrAPI.photo(fromJSON: photoJSON, andFeedType: feedType, into: context) {
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
    
    private func processPhotoRequest(feedType: FeedType, data: Data?, error: Error?, withContainer container: NSPersistentContainer, completion: @escaping (PhotosResult) -> Void) {
        guard let jsonData = data else {
            completion(.failure(error!))
            return
        }
     
        container.performBackgroundTask { context in
            let result = FlickrAPI.photos(fromJSON: jsonData, andFeedType: feedType, into: context)
            do {
                try context.save()
            } catch {
                print("Error saving to Core Data: \(error).")
                completion(.failure(error))
                return
            }
            
            switch result {
            case let .success(photos):
                let photoIDs = photos.map { return $0.objectID }
                let viewContext = container.viewContext
                let viewContextPhotos =
                    photoIDs.map { return viewContext.object(with: $0) } as! [Photo]
                completion(.success(viewContextPhotos))
            case .failure:
                completion(result)
            }
        }
    }
    
    private func processImageRequest(data: Data?, error: Error?) -> ImageResult {
        guard
            let imageData = data,
            let image = UIImage(data: imageData) else {
                
            // Couldn't create an image
            if data == nil {
                return .failure(error!)
            } else {
                return .failure(PhotoError.imageCreationError)
            }
        }
        
        return .success(image)
    }
    
    
    func fetchAllPhotos(forFeedType feedType: FeedType, completion: @escaping (PhotosResult) -> Void) {
        cleanUpPhotos() {
            let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
            let predicate = NSPredicate(format: "\(#keyPath(Photo.feedType)) == \(feedType.rawValue)")
            fetchRequest.predicate = predicate
            
            let sortByDateTaken = NSSortDescriptor(key: #keyPath(Photo.dateTaken),
                                                   ascending: true)
            fetchRequest.sortDescriptors = [sortByDateTaken]
            let viewContext = self.recentPhotosContainer.viewContext
            viewContext.perform {
                do {
                    let allPhotos = try viewContext.fetch(fetchRequest)
                    completion(.success(allPhotos))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func cleanUpPhotos(completion: @escaping ()->()) {
        let cutoffDate = Date().addingTimeInterval(-3600 * 36) //anything older than 36 hours
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "\(#keyPath(Photo.dateUploaded)) < %@", cutoffDate as NSDate)
        fetchRequest.predicate = predicate

        let viewContext = recentPhotosContainer.viewContext
        viewContext.perform {
            if let oldPhotos = try? viewContext.fetch(fetchRequest) {
                oldPhotos.forEach { photo in
                    viewContext.delete(photo)
                }
            }
        }
        completion()
    }
    
    func fetchAllTags(completion: @escaping (TagsResult) -> Void) {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        let sortByName = NSSortDescriptor(key: #keyPath(Tag.name), ascending: true)
        fetchRequest.sortDescriptors = [sortByName]
        let viewContext = recentPhotosContainer.viewContext
        viewContext.perform {
            do {
                let allTags = try fetchRequest.execute()
                completion(.success(allTags))
            } catch {
                completion(.failure(error))
            }
        } }
    
}
