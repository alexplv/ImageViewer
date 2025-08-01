//
//  ThumbnailsViewController.swift
//  ImageViewer
//
//  Created by Zeno Foltin on 07/07/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//
import UIKit

class ThumbnailsViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout,
    UINavigationBarDelegate
{
    fileprivate let reuseIdentifier = "ThumbnailCell"
    fileprivate let sectionInsets = UIEdgeInsets(top: 50.0, left: 20.0, bottom: 50.0, right: 20.0)
    fileprivate var isAnimating = false
    fileprivate let rotationAnimationDuration = 0.2
    var onItemSelected: ((Int) -> Void)?
    let layout = UICollectionViewFlowLayout()
    weak var itemsDataSource: GalleryItemsDataSource!
    var closeButton: UIButton?
    var closeLayout: ButtonLayout?
    required init(itemsDataSource: GalleryItemsDataSource) {
        self.itemsDataSource = itemsDataSource
        super.init(collectionViewLayout: layout)
        NotificationCenter.default.addObserver(
            self, selector: #selector(rotate), name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc func rotate() {
        guard UIApplication.isPortraitOnly else { return }
        guard UIDevice.current.orientation.isFlat == false && isAnimating == false else { return }
        isAnimating = true
        UIView.animate(
            withDuration: rotationAnimationDuration, delay: 0,
            options: UIView.AnimationOptions.curveLinear,
            animations: { [weak self] () in
                self?.view.transform = windowRotationTransform()
                self?.view.bounds = rotationAdjustedBounds()
                self?.view.setNeedsLayout()
                self?.view.layoutIfNeeded()
            }
        ) { [weak self] _ in self?.isAnimating = false }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let screenWidth = view.frame.width
        layout.sectionInset = UIEdgeInsets(top: 50, left: 8, bottom: 8, right: 8)
        layout.itemSize = CGSize(width: screenWidth / 3 - 8, height: screenWidth / 3 - 8)
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        collectionView?.register(ThumbnailCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        addCloseButton()
    }

    fileprivate func addCloseButton() {
        guard let closeButton = closeButton, let closeLayout = closeLayout else { return }
        switch closeLayout {
        case let .pinRight(marginTop, marginRight):
            closeButton.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
            closeButton.frame.origin.x =
                view.bounds.size.width - marginRight - closeButton.bounds.size.width
            closeButton.frame.origin.y = marginTop
        case let .pinLeft(marginTop, marginLeft):
            closeButton.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
            closeButton.frame.origin.x = marginLeft
            closeButton.frame.origin.y = marginTop
        }
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(closeButton)
    }

    @objc func close() { dismiss(animated: true, completion: nil) }
    override func collectionView(
        _: UICollectionView, numberOfItemsInSection _: Int
    ) -> Int { return itemsDataSource.itemCount() }
    override func collectionView(
        _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell =
            collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
                as! ThumbnailCell
        let item = itemsDataSource.provideGalleryItem((indexPath as NSIndexPath).row)
        switch item {
        case let .image(fetchImageBlock):
            fetchImageBlock { image in if let image = image { cell.imageView.image = image } }
        case let .video(fetchImageBlock, _):
            fetchImageBlock { image in if let image = image { cell.imageView.image = image } }
        case let .custom(fetchImageBlock, _):
            fetchImageBlock { image in if let image = image { cell.imageView.image = image } }
        }
        return cell
    }

    override func collectionView(
        _: UICollectionView, didSelectItemAt indexPath: IndexPath
    ) {
        onItemSelected?((indexPath as NSIndexPath).row)
        close()
    }
}
