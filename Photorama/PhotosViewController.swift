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
    let thumbnailStore = ThumbnailStore()

    var selectedFilter = ImageProcessor.Filter.none
    var selectedFeedType: FeedType = .interesting

    var requests: [IndexPath:ImageProcessingRequest] = [:]
    
    var currentLayout: UICollectionViewLayout = UICollectionViewFlowLayout()
    var pinchGR: UIPinchGestureRecognizer?
    
    private var initialScale: CGFloat = 1.0
    private var isTransitioning: Bool = false
    private var transitionLayout: UICollectionViewTransitionLayout?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        pinchGR = UIPinchGestureRecognizer(target: self, action: #selector(PhotosViewController.pinched(_:)))
        
        collectionView.collectionViewLayout = currentLayout
        collectionView.dataSource = photoDataSource
        collectionView.delegate = self

        refreshControl.tintColor = UIColor.gray
        refreshControl.addTarget(self, action: #selector(PhotosViewController.refresh), for: .valueChanged)
        collectionView.addSubview(refreshControl)
        collectionView.alwaysBounceVertical = true

        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        clearRequests()
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
    
    @IBAction func toggleLayout(_ sender: Any) {
        if currentLayout is FlipLayout || currentLayout is SpaceFillingFlowLayout {
            currentLayout = UICollectionViewFlowLayout()
            if let gr = pinchGR {
                collectionView.removeGestureRecognizer(gr)
            }
        } else {
            currentLayout = SpaceFillingFlowLayout()
            if let gr = pinchGR {
                collectionView.addGestureRecognizer(gr)
            }
        }
        
        self.collectionView.setCollectionViewLayout(currentLayout, animated: true)
    }

    @objc private func pinched(_ gr: UIPinchGestureRecognizer) {
        switch gr.state {
        case .began:
            if let currentLayout = collectionView?.collectionViewLayout {
                let nextLayout = currentLayout is FlipLayout ? SpaceFillingFlowLayout() : FlipLayout()
                transitionLayout = collectionView?.startInteractiveTransition(to: nextLayout)
            }
        case .changed:
            let progress: CGFloat
            let startingScale: CGFloat = 1.0
            let currentScale = gr.scale
            let targetScale: CGFloat
            if transitionLayout?.nextLayout is FlipLayout {
                targetScale = 0.25
                progress = (startingScale - currentScale) / (startingScale - targetScale)
            } else {
                targetScale = 4.0
                progress = (currentScale - startingScale) / (targetScale - startingScale)
            }
            transitionLayout?.transitionProgress = progress
        case .ended:
            guard let transitionProgress = transitionLayout?.transitionProgress else {
                collectionView?.cancelInteractiveTransition()
                return
            }
            if transitionProgress > 0.7 {
                collectionView?.finishInteractiveTransition()
            } else {
                collectionView?.cancelInteractiveTransition()
            }
        default: break
        }
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
                let sortedPhotos = photos.sorted(by: { (a, b) in
                    if let aDate = a.dateUploaded as Date?, let bDate = b.dateUploaded as Date? {
                        return aDate > bDate
                    }
                    return false
                })

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
        clearRequests()
        refresh()
    }

    @IBAction func filterChoiceChanged(sender: UISegmentedControl) {
        enum FilterChoice: Int {
            case none = 0, gloom, sepia, blur, mono
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
        case .mono:
            selectedFilter = .mono(color: UIColor.cyan, intensity: 3.0)
        }

        thumbnailStore.clearThumbnails()
        clearRequests()
        collectionView.reloadData()
    }

    func clearRequests() {
        requests.forEach { r in
            r.value.cancel()
        }
        requests.removeAll()
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

        if let request = requests[indexPath] {
            request.priority = .high
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

            // Prepare the actions for thumbnail creation
            let maxSize = CGSize(width: 200, height: 200)
            let scaleAction = ImageProcessor.Action.scale(maxSize: maxSize)
            let faceFuzzAction = ImageProcessor.Action.pixellatedFaces
            let filterAction = ImageProcessor.Action.filter(self.selectedFilter)
            let actions = [scaleAction, filterAction, faceFuzzAction]

            let request = self.imageProcessor.process(image: image, actions: actions, priority: .high) { thumbResult in
                // Actually process the available photo into a thumbnail
                let thumbnail: UIImage
                switch thumbResult {
                case .success(let filteredImage):
                    thumbnail = filteredImage
                case .failure(let error):
                    print("Error: unable to generate filtered thumbnail for \(String(describing: photo.photoID)): \(error)")
                    thumbnail = image
                case .cancelled:
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
                    
                    self.requests[indexPath] = nil
                }
            }
            
            OperationQueue.main.addOperation {
                self.requests[indexPath] = request
            }

        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        requests[indexPath] = nil
    }
    
    func collectionView(_ collectionView: UICollectionView, transitionLayoutForOldLayout fromLayout: UICollectionViewLayout, newLayout toLayout: UICollectionViewLayout) -> UICollectionViewTransitionLayout {
        
        return UICollectionViewTransitionLayout(currentLayout: fromLayout, nextLayout: toLayout)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize{
        return CGSize(width: 140, height: 140)
    }
    
}
