//
//  ItemViewController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 01/07/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//
import UIKit

typealias Duration = TimeInterval
public protocol ItemController: AnyObject {
    var index: Int { get }
    var isInitialController: Bool { get set }
    var delegate: ItemControllerDelegate? { get set }
    var displacedViewsDataSource: GalleryDisplacedViewsDataSource? { get set }
    func fetchImage()
    func presentItem(alongsideAnimation: @escaping () -> Void, completion: @escaping () -> Void)
    func dismissItem(alongsideAnimation: @escaping () -> Void, completion: @escaping () -> Void)
    func closeDecorationViews(_ duration: TimeInterval)
}
