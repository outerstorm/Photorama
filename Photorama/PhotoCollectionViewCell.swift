//
//  PhotoCollectionViewCell.swift
//  Photorama
//
//  Created by Justin Storm on 3/29/17.
//  Copyright © 2017 McKesson. All rights reserved.
//

import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy h:mm a"
        return formatter
    }()

    @IBOutlet var imageView: UIImageView!
    @IBOutlet var dateUploaded: UILabel!
    @IBOutlet var spinner: UIActivityIndicatorView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        update(with: nil, andDateUploaded: nil)
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        update(with: nil, andDateUploaded: nil)
    }
    
    func update(with image: UIImage?, andDateUploaded date: Date?) {
        if let imageToDisplay = image {
            spinner.stopAnimating()
            imageView.image = imageToDisplay
            if let date = date {
                dateUploaded.text = PhotoCollectionViewCell.dateFormatter.string(from: date)
            }
        } else {
            spinner.startAnimating()
            imageView.image = nil
            dateUploaded.text = nil
        }
    }
}
