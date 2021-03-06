//
//  PhotoInfoViewController.swift
//  Photorama
//
//  Created by Justin Storm on 3/29/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import UIKit

class PhotoInfoViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet var imageView: UIImageView!

    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!

    var photo: Photo! {
        didSet {
            navigationItem.title = photo.title
        }
    }
    var store: PhotoStore!
    var imageProcessor: ImageProcessor!
    var activeFilter: ImageProcessor.Filter!

    var request: ImageProcessingRequest?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        store.fetchImage(for: photo) { (result) -> Void in
            switch result {
            case let .success(image):

                let fuzzAction = ImageProcessor.Action.pixellatedFaces
                let filterAction = ImageProcessor.Action.filter(self.activeFilter)
                let actions = [fuzzAction, filterAction]

                self.request = self.imageProcessor.process(image: image, actions: actions, priority: .high) { actionResult in
                    let bigImage: UIImage
                    switch actionResult {
                    case .success(let filteredImage):
                        bigImage = filteredImage
                    case .failure(let error):
                        print("Error: failed to process photo \(String(describing: self.photo.photoID)): \(error)")
                        bigImage = image
                        //TODO:  present an error alert maybe?
                    case .cancelled:
                        bigImage = image
                    }

                    OperationQueue.main.addOperation {
                        self.imageView.image = bigImage
                    }
                }

            case let .failure(error):
                print("Error fetching image for photo: \(error)")
            }
        }

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        request?.cancel()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateMinZoomScaleForSize(size: view.bounds.size)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "showTags"?:
            let navController = segue.destination as! UINavigationController
            let tagController = navController.topViewController as! TagsViewController
            tagController.store = store
            tagController.photo = photo
        default:
            preconditionFailure("Unexpected segue identifier.")
        }
    }

    private func updateMinZoomScaleForSize(size: CGSize) {
        let imageWidth = imageView.bounds.width
        let imageHeight = imageView.bounds.height
        if imageWidth == 0 || imageHeight == 0 {
            return
        }

        let widthScale = size.width / imageWidth
        let heightScale = size.height / imageHeight
        let minScale = min(widthScale, heightScale)
        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale
    }
}

extension PhotoInfoViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}
