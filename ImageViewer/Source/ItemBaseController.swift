//
//  ItemBaseController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 01/08/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//
import UIKit

public protocol ItemView { var image: UIImage? { get set } }
open class ItemBaseController<T: UIView>: UIViewController, ItemController,
    UIGestureRecognizerDelegate, UIScrollViewDelegate
    where T: ItemView
{
    // UI
    public var itemView = T()
    let scrollView = UIScrollView()
    let activityIndicatorView = UIActivityIndicatorView(style: .white)
    // DELEGATE / DATASOURCE
    public weak var delegate: ItemControllerDelegate?
    public weak var displacedViewsDataSource: GalleryDisplacedViewsDataSource?
    // STATE
    public let index: Int
    public var isInitialController = false
    let itemCount: Int
    var swipingToDismiss: SwipeToDismiss?
    fileprivate var isAnimating = false
    fileprivate var fetchImageBlock: FetchImageBlock
    // CONFIGURATION
    fileprivate var presentationStyle = GalleryPresentationStyle.displacement
    fileprivate var doubleTapToZoomDuration = 0.15
    fileprivate var displacementDuration: TimeInterval = 0.55
    fileprivate var reverseDisplacementDuration: TimeInterval = 0.25
    fileprivate var itemFadeDuration: TimeInterval = 0.3
    fileprivate var displacementTimingCurve: UIView.AnimationCurve = .linear
    fileprivate var displacementSpringBounce: CGFloat = 0.95
    fileprivate let minimumZoomScale: CGFloat = 1
    fileprivate var maximumZoomScale: CGFloat = 8
    fileprivate var pagingMode: GalleryPagingMode = .standard
    fileprivate var thresholdVelocity: CGFloat =
        500 // The speed of swipe needs to be at least this amount of pixels per
    // second for the swipe to finish dismissal.
    fileprivate var displacementKeepOriginalInPlace = false
    fileprivate var displacementInsetMargin: CGFloat = 50
    fileprivate var swipeToDismissMode = GallerySwipeToDismissMode.always
    fileprivate var toggleDecorationViewBySingleTap = true
    fileprivate var activityViewByLongPress = true
    /// INTERACTIONS
    fileprivate var singleTapRecognizer: UITapGestureRecognizer?
    fileprivate var longPressRecognizer: UILongPressGestureRecognizer?
    fileprivate let doubleTapRecognizer = UITapGestureRecognizer()
    fileprivate let swipeToDismissRecognizer = UIPanGestureRecognizer()
    // TRANSITIONS
    fileprivate var swipeToDismissTransition: GallerySwipeToDismissTransition?

    // MARK: - Initializers

    public init(
        index: Int, itemCount: Int, fetchImageBlock: @escaping FetchImageBlock,
        configuration: GalleryConfiguration, isInitialController: Bool = false
    ) {
        self.index = index
        self.itemCount = itemCount
        self.isInitialController = isInitialController
        self.fetchImageBlock = fetchImageBlock
        for item in configuration {
            switch item {
            case let .swipeToDismissThresholdVelocity(velocity): thresholdVelocity =
                velocity
            case let .doubleTapToZoomDuration(duration): doubleTapToZoomDuration =
                duration
            case let .presentationStyle(style): presentationStyle = style
            case let .pagingMode(mode): pagingMode = mode
            case let .displacementDuration(duration): displacementDuration =
                duration
            case let .reverseDisplacementDuration(duration): reverseDisplacementDuration =
                duration
            case let .displacementTimingCurve(curve): displacementTimingCurve =
                curve
            case let .maximumZoomScale(scale): maximumZoomScale = scale
            case let .itemFadeDuration(duration): itemFadeDuration = duration
            case let .displacementKeepOriginalInPlace(keep): displacementKeepOriginalInPlace =
                keep
            case let .displacementInsetMargin(margin): displacementInsetMargin =
                margin
            case let .swipeToDismissMode(mode): swipeToDismissMode = mode
            case let .toggleDecorationViewsBySingleTap(enabled): toggleDecorationViewBySingleTap =
                enabled
            case let .activityViewByLongPress(enabled): activityViewByLongPress =
                enabled
            case let .spinnerColor(color): activityIndicatorView.color = color
            case let .spinnerStyle(style): activityIndicatorView.style = style
            case let .displacementTransitionStyle(style):
                switch style {
                case let .springBounce(bounce): displacementSpringBounce =
                    bounce
                case .normal: displacementSpringBounce = 1
                }
            default: break
            }
        }
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        itemView.isHidden = isInitialController
        configureScrollView()
        configureGestureRecognizers()
        activityIndicatorView.hidesWhenStopped = true
    }

    @available(*, unavailable) public required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit { self.scrollView.removeObserver(self, forKeyPath: "contentOffset") }

    // MARK: - Configuration

    fileprivate func configureScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = UIScrollView.DecelerationRate.fast
        scrollView.contentInset = UIEdgeInsets.zero
        scrollView.contentOffset = CGPoint.zero
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = max(
            maximumZoomScale,
            aspectFillZoomScale(
                forBoundingSize: view.bounds.size,
                contentSize: itemView.bounds.size
            )
        )
        scrollView.delegate = self
        scrollView.addObserver(
            self, forKeyPath: "contentOffset",
            options: NSKeyValueObservingOptions.new, context: nil
        )
    }

    func configureGestureRecognizers() {
        doubleTapRecognizer.addTarget(
            self,
            action: #selector(scrollViewDidDoubleTap(_:))
        )
        doubleTapRecognizer.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapRecognizer)
        if toggleDecorationViewBySingleTap == true {
            let singleTapRecognizer = UITapGestureRecognizer()
            singleTapRecognizer.addTarget(
                self,
                action: #selector(scrollViewDidSingleTap)
            )
            singleTapRecognizer.numberOfTapsRequired = 1
            scrollView.addGestureRecognizer(singleTapRecognizer)
            singleTapRecognizer.require(toFail: doubleTapRecognizer)
            self.singleTapRecognizer = singleTapRecognizer
        }
        if activityViewByLongPress == true {
            let longPressRecognizer = UILongPressGestureRecognizer()
            longPressRecognizer.addTarget(
                self,
                action: #selector(scrollViewDidLongPress)
            )
            scrollView.addGestureRecognizer(longPressRecognizer)
            self.longPressRecognizer = longPressRecognizer
        }
        if swipeToDismissMode != .never {
            swipeToDismissRecognizer.addTarget(
                self,
                action: #selector(scrollViewDidSwipeToDismiss)
            )
            swipeToDismissRecognizer.delegate = self
            view.addGestureRecognizer(swipeToDismissRecognizer)
            swipeToDismissRecognizer.require(toFail: doubleTapRecognizer)
        }
    }

    fileprivate func createViewHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(itemView)
        activityIndicatorView.startAnimating()
        view.addSubview(activityIndicatorView)
    }

    // MARK: - View Controller Lifecycle

    override open func viewDidLoad() {
        super.viewDidLoad()
        createViewHierarchy()
        fetchImage()
    }

    public func fetchImage() {
        fetchImageBlock { [weak self] image in
            if let image {
                DispatchQueue.main.async {
                    self?.activityIndicatorView.stopAnimating()
                    var itemView = self?.itemView
                    itemView?.image = image
                    itemView?.isAccessibilityElement = image
                        .isAccessibilityElement
                    itemView?.accessibilityLabel = image.accessibilityLabel
                    itemView?.accessibilityTraits = image.accessibilityTraits
                    self?.view.setNeedsLayout()
                    self?.view.layoutIfNeeded()
                }
            }
        }
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        delegate?.itemControllerWillAppear(self)
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        delegate?.itemControllerDidAppear(self)
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.itemControllerWillDisappear(self)
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        activityIndicatorView.center = view.boundsCenter
        if let size = itemView.image?.size, size != CGSize.zero {
            let aspectFitItemSize = aspectFitSize(
                forContentOfSize: size, inBounds: scrollView.bounds.size
            )
            itemView.bounds.size = aspectFitItemSize
            scrollView.contentSize = itemView.bounds.size
            itemView.center = scrollView.boundsCenter
        }
    }

    public func viewForZooming(in _: UIScrollView) -> UIView? { itemView }

    // MARK: - Scroll View delegate methods

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        itemView.center = contentCenter(
            forBoundingSize: scrollView.bounds.size,
            contentSize: scrollView.contentSize
        )
    }

    @objc func scrollViewDidSingleTap() {
        delegate?.itemControllerDidSingleTap(self)
    }

    @objc func scrollViewDidLongPress() {
        delegate?.itemControllerDidLongPress(self, in: itemView)
    }

    @objc func scrollViewDidDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let touchPoint = recognizer.location(ofTouch: 0, in: itemView)
        let aspectFillScale = aspectFillZoomScale(
            forBoundingSize: scrollView.bounds.size,
            contentSize: itemView.bounds.size
        )
        if scrollView.zoomScale == 1.0 || scrollView
            .zoomScale > aspectFillScale
        {
            let zoomRectangle = zoomRect(
                ForScrollView: scrollView, scale: aspectFillScale,
                center: touchPoint
            )
            UIView.animate(
                withDuration: doubleTapToZoomDuration, delay: 0,
                usingSpringWithDamping: 1.0, // soft, no bounce
                initialSpringVelocity: 0.0, // no kick
                options: [.beginFromCurrentState],
                animations: { [weak self] in self?.scrollView.zoom(
                    to: zoomRectangle,
                    animated: false
                ) },
                completion: nil
            )
        } else {
            UIView.animate(
                withDuration: doubleTapToZoomDuration, delay: 0,
                usingSpringWithDamping: 1.0,
                initialSpringVelocity: 0.0, options: [.beginFromCurrentState],
                animations: { [weak self] in self?.scrollView.setZoomScale(
                    1.0,
                    animated: false
                ) },
                completion: nil
            )
        }
    }

    @objc func scrollViewDidSwipeToDismiss(
        _ recognizer: UIPanGestureRecognizer
    ) {
        /// A deliberate UX decision...you have to zoom back in to scale 1 to be
        /// able to swipe to dismiss. It is difficult for the user to swipe to
        /// dismiss from images larger then screen bounds because almost all the
        /// time it's not swiping to dismiss but instead panning a zoomed in
        /// picture on the canvas.
        guard scrollView.zoomScale == scrollView.minimumZoomScale
        else { return }
        let currentVelocity = recognizer.velocity(in: view)
        let currentTouchPoint = recognizer.translation(in: view)
        if swipingToDismiss == nil {
            swipingToDismiss =
                (abs(currentVelocity.x) > abs(currentVelocity.y)) ?
                .horizontal :
                .vertical
        }
        guard let swipingToDismissInProgress = swipingToDismiss else { return }
        switch recognizer.state {
        case .began:
            swipeToDismissTransition =
                GallerySwipeToDismissTransition(scrollView: scrollView)
        case .changed:
            handleSwipeToDismissInProgress(
                swipingToDismissInProgress, forTouchPoint: currentTouchPoint
            )
        case .ended:
            handleSwipeToDismissEnded(
                swipingToDismissInProgress, finalVelocity: currentVelocity,
                finalTouchPoint: currentTouchPoint
            )
        default: break
        }
    }

    // MARK: - Swipe To Dismiss

    func handleSwipeToDismissInProgress(
        _ swipeOrientation: SwipeToDismiss, forTouchPoint touchPoint: CGPoint
    ) {
        switch (swipeOrientation, index) {
        case (.horizontal, 0) where itemCount != 1:
            /// edge case horizontal first index - limits the swipe to dismiss
            /// to HORIZONTAL RIGHT direction.
            swipeToDismissTransition?
                .updateInteractiveTransition(horizontalOffset: min(
                    0,
                    -touchPoint.x
                ))
        case (.horizontal, itemCount - 1) where itemCount != 1:
            /// edge case horizontal last index - limits the swipe to dismiss to
            /// HORIZONTAL LEFT direction.
            swipeToDismissTransition?
                .updateInteractiveTransition(horizontalOffset: max(
                    0,
                    -touchPoint.x
                ))
        case (.horizontal, _):
            swipeToDismissTransition?
                .updateInteractiveTransition(horizontalOffset: -touchPoint
                    .x) // all the rest
        case (.vertical, _):
            swipeToDismissTransition?
                .updateInteractiveTransition(verticalOffset: -touchPoint
                    .y) // all the rest
        }
    }

    func handleSwipeToDismissEnded(
        _ swipeOrientation: SwipeToDismiss, finalVelocity velocity: CGPoint,
        finalTouchPoint touchPoint: CGPoint
    ) {
        let maxIndex = itemCount - 1
        let swipeToDismissCompletionBlock = { [weak self] in
            UIApplication.applicationWindow.windowLevel = UIWindow.Level.normal
            self?.swipingToDismiss = nil
            self?.delegate?.itemControllerDidFinishSwipeToDismissSuccessfully()
        }
        switch (swipeOrientation, index) {
        /// Any item VERTICAL UP direction
        case (.vertical, _) where velocity.y < -thresholdVelocity:
            swipeToDismissTransition?.finishInteractiveTransition(
                swipeOrientation, touchPoint: touchPoint.y,
                targetOffset: (view.bounds.height / 2) +
                    (itemView.bounds.height / 2),
                escapeVelocity: velocity.y,
                completion: swipeToDismissCompletionBlock
            )
        /// Any item VERTICAL DOWN direction
        case (.vertical, _) where thresholdVelocity < velocity.y:
            dismissItem(
                alongsideAnimation: {},
                completion: swipeToDismissCompletionBlock
            )
        //            swipeToDismissTransition?.finishInteractiveTransition(
        //                swipeOrientation,
        //                touchPoint: touchPoint.y,
        //                targetOffset: -(view.bounds.height / 2) - (itemView.bounds.height / 2),
        //                escapeVelocity: velocity.y,
        //                completion: swipeToDismissCompletionBlock
        //            )
        /// First item HORIZONTAL RIGHT direction
        case (.horizontal, 0) where thresholdVelocity < velocity.x:
            swipeToDismissTransition?.finishInteractiveTransition(
                swipeOrientation, touchPoint: touchPoint.x,
                targetOffset: -(view.bounds.width / 2) -
                    (itemView.bounds.width / 2),
                escapeVelocity: velocity.x,
                completion: swipeToDismissCompletionBlock
            )
        /// Last item HORIZONTAL LEFT direction
        case (.horizontal, maxIndex) where velocity.x < -thresholdVelocity:
            swipeToDismissTransition?.finishInteractiveTransition(
                swipeOrientation, touchPoint: touchPoint.x,
                targetOffset: (view.bounds.width / 2) +
                    (itemView.bounds.width / 2),
                escapeVelocity: velocity.x,
                completion: swipeToDismissCompletionBlock
            )
        /// If none of the above select cases, we cancel.
        default:
            swipeToDismissTransition?
                .cancelTransition { [weak self] in
                    self?.swipingToDismiss = nil
                }
        }
    }

    func animateDisplacedImageToOriginalPosition(
        _ duration: TimeInterval, completion: ((Bool) -> Void)?
    ) {
        guard isAnimating == false else { return }
        isAnimating = true
        UIView.animate(
            withDuration: duration,
            animations: { [weak self] in
                self?.scrollView.zoomScale = self!.scrollView.minimumZoomScale
                if UIApplication.isPortraitOnly {
                    self?.itemView.transform = windowRotationTransform()
                        .inverted()
                }
            },
            completion: { [weak self] finished in
                completion?(finished)
                if finished {
                    UIApplication.applicationWindow.windowLevel = UIWindow.Level
                        .normal
                    self?.isAnimating = false
                }
            }
        )
    }

    // MARK: - Present/Dismiss transitions

    public func presentItem(
        alongsideAnimation: @escaping () -> Void,
        completion: @escaping () -> Void
    ) {
        guard isAnimating == false else { return }
        isAnimating = true
        if var displacedView = displacedViewsDataSource?
            .provideDisplacementItem(atIndex: index),
            let image = displacedView.image
        {
            if presentationStyle == .displacement {
                // Prepare the animated imageView
                let animatedImageView = displacedView.imageView()
                // rotate the imageView to starting angle
                if UIApplication.isPortraitOnly == true {
                    animatedImageView.transform = deviceRotationTransform()
                }
                // position the image view to starting center
                animatedImageView.center = displacedView.convert(
                    displacedView.boundsCenter,
                    to: view
                )
                animatedImageView.clipsToBounds = true
                view.addSubview(animatedImageView)
                if displacementKeepOriginalInPlace ==
                    false { displacedView.isHidden = true }
                UIView.animate(
                    withDuration: displacementDuration, delay: 0,
                    usingSpringWithDamping: displacementSpringBounce,
                    initialSpringVelocity: 0.0,
                    options: [.beginFromCurrentState],
                    animations: { [weak self] in
                        alongsideAnimation()
                        if UIApplication.isPortraitOnly == true {
                            animatedImageView.transform = CGAffineTransform
                                .identity
                        }
                        /// Animate it into the center (with optionally
                        /// rotating) - that basically includes changing the
                        /// size and position
                        animatedImageView.bounds.size =
                            self?
                                .displacementTargetSize(forSize: image.size) ??
                                image.size
                        animatedImageView.center = self?.view
                            .boundsCenter ?? CGPoint.zero
                    },
                    completion: { [weak self] _ in
                        self?.itemView.isHidden = false
                        displacedView.isHidden = false
                        animatedImageView.removeFromSuperview()
                        self?.isAnimating = false
                        completion()
                    }
                )
            }
        } else {
            itemView.alpha = 0
            itemView.isHidden = false
            UIView.animate(
                withDuration: itemFadeDuration,
                animations: { [weak self] in self?.itemView.alpha = 1 },
                completion: { [weak self] _ in
                    completion()
                    self?.isAnimating = false
                }
            )
        }
    }

    func displacementTargetSize(forSize size: CGSize) -> CGSize {
        let boundingSize = rotationAdjustedBounds().size
        return aspectFitSize(forContentOfSize: size, inBounds: boundingSize)
    }

    func findVisibleDisplacedView() -> DisplaceableView? {
        guard let displacedView = displacedViewsDataSource?
            .provideDisplacementItem(atIndex: index)
        else { return nil }
        let displacedViewFrame = displacedView.frameInCoordinatesOfScreen()
        let validAreaFrame = view.frame.insetBy(
            dx: displacementInsetMargin, dy: displacementInsetMargin
        )
        let isVisibleEnough = displacedViewFrame.intersects(validAreaFrame)
        return isVisibleEnough ? displacedView : nil
    }

    public func dismissItem(
        alongsideAnimation: @escaping () -> Void,
        completion: @escaping () -> Void
    ) {
        guard isAnimating == false else { return }
        isAnimating = true
        switch presentationStyle {
        case .displacement:
            if let displacedView = findVisibleDisplacedView() {
                if displacementKeepOriginalInPlace == false { displacedView.isHidden = true }
                UIView.animate(
                    withDuration: reverseDisplacementDuration, delay: 0,
                    usingSpringWithDamping: 0.95, // 0.7–0.9 for soft spring
                    initialSpringVelocity: 0.0, // tweak 0.0–0.5 for kick
                    options: [.beginFromCurrentState, .allowAnimatedContent],
                    animations: { [weak self] in
                        guard let self else { return }
                        self.scrollView.zoomScale = 1
                        alongsideAnimation()
                        delegate?
                            .itemControllerDismissAlongsideAnimation(self)()
                        if UIApplication
                            .isPortraitOnly
                        {
                            self.itemView.transform = deviceRotationTransform()
                        }
                        self.itemView.bounds = displacedView.bounds
                        self.itemView.center = displacedView.convert(
                            displacedView.boundsCenter,
                            to: self.view
                        )
                        self.itemView.clipsToBounds = true
                        self.itemView.contentMode = displacedView.contentMode
                        self.scrollView
                            .contentOffset =
                            .zero // reset the scroll view offset to fix
                        // itemView to its original position
                    },
                    completion: { [weak self] _ in
                        self?.isAnimating = false
                        displacedView.isHidden = false
                        completion()
                    }
                )
            } else {
                fallthrough
            }
        case .fade:
            UIView.animate(
                withDuration: itemFadeDuration,
                animations: { [weak self] in self?.itemView.alpha = 0 },
                completion: { [weak self] _ in
                    self?.isAnimating = false
                    completion()
                }
            )
        }
    }

    // MARK: - Arcane stuff

    /// This resolves which of the two pan gesture recognizers should kick in.
    /// There is one built in the GalleryViewController (as it is a
    /// UIPageViewController subclass), and another one is added as part of item
    /// controller. When we pan, we need to decide whether it constitutes a
    /// horizontal paging gesture, or a horizontal swipe-to-dismiss gesture.
    /// All the logic is from the perspective of SwipeToDismissRecognizer -
    /// should it kick in (or let the paging recognizer page)?
    public func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    )
        -> Bool
    {
        /// We only care about the swipe to dismiss gesture recognizer, not the
        /// built-in pan recognizer that handles paging.
        guard gestureRecognizer == swipeToDismissRecognizer
        else { return false }
        /// The velocity vector will help us make the right decision
        let velocity = swipeToDismissRecognizer
            .velocity(in: swipeToDismissRecognizer.view)
        /// A bit of paranoia
        guard velocity.orientation != .none else { return false }
        /// We continue if the swipe is horizontal, otherwise it's Vertical and
        /// it is swipe to dismiss.
        guard velocity.orientation == .horizontal
        else { return swipeToDismissMode.contains(.vertical) }
        /// A special case for horizontal "swipe to dismiss" is when the gallery
        /// has carousel mode OFF, then it is possible to reach the beginning or
        /// the end of image set while paging. Paging will stop at index = 0 or
        /// at index.max. In this case we allow to jump out from the gallery
        /// also via horizontal swipe to dismiss.
        if (index == 0 && velocity.direction == .right)
            || (index == itemCount - 1 && velocity.direction == .left)
        {
            return pagingMode == .standard && swipeToDismissMode
                .contains(.horizontal)
        }
        return false
    }

    // Reports the continuous progress of Swipe To Dismiss to the Gallery View
    // Controller
    override open func observeValue(
        forKeyPath keyPath: String?, of _: Any?,
        change _: [NSKeyValueChangeKey: Any]?,
        context _: UnsafeMutableRawPointer?
    ) {
        guard let swipingToDismissInProgress = swipingToDismiss else { return }
        guard keyPath == "contentOffset", !isAnimating else { return }
        let distanceToEdge: CGFloat
        let percentDistance: CGFloat
        switch swipingToDismissInProgress {
        case .horizontal:
            distanceToEdge = (scrollView.bounds.width / 2) +
                (itemView.bounds.width / 2)
            percentDistance = abs(scrollView.contentOffset.x / distanceToEdge)
        case .vertical:
            distanceToEdge = (scrollView.bounds.height / 2) +
                (itemView.bounds.height / 2)
            percentDistance = abs(scrollView.contentOffset.y / distanceToEdge)
        }
        delegate?.itemController(
            self,
            didSwipeToDismissWithDistanceToEdge: percentDistance
        )
    }

    public func closeDecorationViews(_: TimeInterval) {
        // stub
    }
}
