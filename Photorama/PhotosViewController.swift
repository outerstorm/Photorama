//
//  ViewController.swift
//  Photorama
//
//  Created by Justin Storm on 3/29/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import UIKit

class PhotosViewController: UIViewController {

    @IBOutlet var collectionView: UICollectionView!
    var store: PhotoStore!
    let photoDataSource = PhotoDataSource()
    let refreshControl = UIRefreshControl()
    
    let imageProcessor = ImageProcessor()
    let processingQueue = OperationQueue()
    let thumbnailStore = ThumbnailStore()
    
    var selectedFilter = ImageProcessor.Filter.none
    var selectedFeedType: FeedType = .interesting
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        collectionView.dataSource = photoDataSource
        collectionView.delegate = self
        
        refreshControl.tintColor = UIColor.gray
        refreshControl.addTarget(self, action: #selector(PhotosViewController.refresh), for: .valueChanged)
        collectionView.addSubview(refreshControl)
        collectionView.alwaysBounceVertical = true
        
        refresh()
    }

    @objc private func refresh() {
        updateDataSource()
        
        if selectedFeedType == .interesting {
            store.fetchInterestingPhotos { photosResult in
                self.refreshControl.endRefreshing()
                self.updateDataSource()
            }
            
        } else if selectedFeedType == .recent {
            store.fetchRecentPhotos { photosResult in
                self.refreshControl.endRefreshing()
                self.updateDataSource()
            }
            
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "showPhoto"?:
            if let selectedIndexPath =
                collectionView.indexPathsForSelectedItems?.first {
                let photo = photoDataSource.photos[selectedIndexPath.row]
                let destinationVC = segue.destination as! PhotoInfoViewController
                destinationVC.photo = photo
                destinationVC.store = store
                destinationVC.imageProcessor = imageProcessor
                destinationVC.activeFilter = selectedFilter
            } default:
                preconditionFailure("Unexpected segue identifier.")
        }
    }
    
    private func updateDataSource() {
        store.fetchAllPhotos(forFeedType: selectedFeedType) {
            (photosResult) in
            switch photosResult {
            case let .success(photos):
                let sortedPhotos = photos.sorted(by: { (a,b) in
                    if let aDate = a.dateUploaded as Date?, let bDate = b.dateUploaded as Date? {
                        return aDate > bDate
                    }
                    return false
                } )
                
                self.photoDataSource.photos = sortedPhotos
            case .failure:
                self.photoDataSource.photos.removeAll()
            }
            self.collectionView.reloadSections(IndexSet(integer: 0))
        }
    }
    
    @IBAction func toggleFeed(_ sender: Any) {
        if selectedFeedType == .interesting {
            selectedFeedType = .recent
        } else {
            selectedFeedType = .interesting
        }
        refresh()
    }
    
    @IBAction func filterChoiceChanged(sender: UISegmentedControl) {
        enum FilterChoice: Int {
            case none = 0, gloom, sepia, blur
        }
        
        guard let choice = FilterChoice(rawValue: sender.selectedSegmentIndex) else {
            fatalError("Impossible segment selected: \(sender.selectedSegmentIndex)")
        }
        
        switch choice {
        case .none:
            selectedFilter = .none
        case .gloom:
            selectedFilter = .gloom(intensity: 3.0, radius: 3.0)
        case .sepia:
            selectedFilter = .sephia(intensity: 3.0)
        case .blur:
            selectedFilter = .blur(radius: 10.0)
        }
        
        thumbnailStore.clearThumbnails()
        collectionView.reloadData()
    }
    
}

extension PhotosViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        let photo = photoDataSource.photos[indexPath.row]
        
        if let photoId = photo.photoID as NSString?,
            let thumbnail = thumbnailStore.thumbnail(forKey: photoId),
            let cell = cell as? PhotoCollectionViewCell {
            
            cell.update(with: thumbnail, andDateUploaded: photo.dateUploaded as Date?)
            
            return
        }
        
        // Download the image data, which could take some time
        store.fetchImage(for: photo) { (result) -> Void in
            // The index path for the photo might have changed between the
            // time the request started and finished, so find the most
            // recent index path
            // (Note: You will have an error on the next line; you will fix it soon)
            guard let photoIndex = self.photoDataSource.photos.index(of: photo),
                case let .success(image) = result else {
                    return
            }
            let photoIndexPath = IndexPath(item: photoIndex, section: 0)
            
            self.processingQueue.addOperation {
                // Prepare the actions for thumbnail creation
                let maxSize = CGSize(width: 200, height: 200)
                let scaleAction = ImageProcessor.Action.scale(maxSize: maxSize)
                let faceFuzzAction = ImageProcessor.Action.pixellatedFaces
                let filterAction = ImageProcessor.Action.filter(self.selectedFilter)
                let actions = [scaleAction, filterAction, faceFuzzAction]
                
                // Actually process the available photo into a thumbnail
                let thumbnail: UIImage
                do {
                    thumbnail = try self.imageProcessor.perform(actions, on: image)
                } catch {
                    print("Error: unable to generate filtered thumbnail for \(photo): \(error)")
                    thumbnail = image
                }
                
                OperationQueue.main.addOperation {
                    if let photoId = photo.photoID as NSString? {
                        self.thumbnailStore.setThumbnail(image: thumbnail, forKey: photoId)
                    }
                    
                    // When the request finishes, only update the cell if it's still visible
                    if let cell = self.collectionView.cellForItem(at: photoIndexPath) as? PhotoCollectionViewCell {
                        cell.update(with: thumbnail, andDateUploaded: photo.dateUploaded as Date?)
                    }
                }
            }
            
        }
    }
}
