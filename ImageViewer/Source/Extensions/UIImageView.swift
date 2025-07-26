//
//  UIImageView.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 19/07/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//
import UIKit

extension DisplaceableView {
    func imageView() -> UIImageView {
        let imageView = UIImageView(image: image)
        imageView.bounds = bounds
        imageView.center = center
        imageView.contentMode = contentMode
        return imageView
    }
}
