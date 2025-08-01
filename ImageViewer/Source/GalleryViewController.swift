//
//  GalleryViewController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 01/07/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//
import AVFoundation
import UIKit

open class GalleryViewController: UIPageViewController, ItemControllerDelegate {
    // UI
    fileprivate let overlayView = BlurView()
    /// A custom view on the top of the gallery with layout using default (or
    /// custom) pinning settings for header.
    open var headerView: UIView?
    /// A custom view at the bottom of the gallery with layout using default (or
    /// custom) pinning settings for footer.
    open var footerView: UIView?
    fileprivate var closeButton: UIButton? = UIButton.closeButton()
    fileprivate var seeAllCloseButton: UIButton? = nil
    fileprivate var thumbnailsButton: UIButton? = UIButton.thumbnailsButton()
    fileprivate var deleteButton: UIButton? = UIButton.deleteButton()
    fileprivate let scrubber = VideoScrubber()
    fileprivate weak var initialItemController: ItemController?
    // LOCAL STATE
    // represents the current page index, updated when the root view of the view
    // controller representing the page stops animating inside visible bounds
    // and stays on screen.
    public var currentIndex: Int
    // Picks up the initial value from configuration, if provided. Subsequently
    // also works as local state for the setting.
    fileprivate var decorationViewsHidden = false
    fileprivate var isAnimating = false
    fileprivate var initialPresentationDone = false
    // DATASOURCE/DELEGATE
    fileprivate let itemsDelegate: GalleryItemsDelegate?
    fileprivate let itemsDataSource: GalleryItemsDataSource
    fileprivate let pagingDataSource: GalleryPagingDataSource
    // CONFIGURATION
    fileprivate var spineDividerWidth: Float = 10
    fileprivate var galleryPagingMode = GalleryPagingMode.standard
    fileprivate var headerLayout = HeaderLayout.center(25)
    fileprivate var footerLayout = FooterLayout.center(25)
    fileprivate var closeLayout = ButtonLayout.pinRight(8, 16)
    fileprivate var seeAllCloseLayout = ButtonLayout.pinRight(8, 16)
    fileprivate var thumbnailsLayout = ButtonLayout.pinLeft(8, 16)
    fileprivate var deleteLayout = ButtonLayout.pinRight(8, 66)
    fileprivate var headerViewVisibilityMode = VisibilityMode.visible
    fileprivate var footerViewVisibilityMode = VisibilityMode.visible
    fileprivate var statusBarHidden = true
    fileprivate var overlayAccelerationFactor: CGFloat = 1
    fileprivate var rotationDuration = 0.15
    fileprivate var rotationMode = GalleryRotationMode.always
    fileprivate let swipeToDismissFadeOutAccelerationFactor: CGFloat = 6
    fileprivate var decorationViewsFadeDuration = 0.15
    fileprivate var displacementDuration = 0.15
    
    // MARK: - Performance Optimization Properties
    
    /// Store configuration for lazy processing
    fileprivate let deferredConfiguration: GalleryConfiguration
    fileprivate var configurationProcessed = false
    fileprivate var continueNextVideoOnFinish = false
    /// COMPLETION BLOCKS
    /// If set, the block is executed right after the initial launch animations
    /// finish.
    open var launchedCompletion: (() -> Void)?
    /// If set, called every time ANY animation stops in the page controller
    /// stops and the viewer passes a page index of the page that is currently
    /// on screen
    open var landedPageAtIndexCompletion: ((Int) -> Void)?
    /// If set, launched after all animations finish when the close button is
    /// pressed.
    open var closedCompletion: (() -> Void)?
    /// If set, launched after all animations finish when the close() method is
    /// invoked via public API.
    open var programmaticallyClosedCompletion: (() -> Void)?
    /// If set, launched after all animations finish when the swipe-to-dismiss
    /// (applies to all directions and cases) gesture is used.
    open var swipedToDismissCompletion: (() -> Void)?
    @available(*, unavailable) public required init?(coder _: NSCoder) {
        fatalError()
    }

    public init(
        startIndex: Int, itemsDataSource: GalleryItemsDataSource,
        itemsDelegate: GalleryItemsDelegate? = nil,
        displacedViewsDataSource: GalleryDisplacedViewsDataSource? = nil,
        configuration: GalleryConfiguration = []
    ) {
        currentIndex = startIndex
        self.itemsDelegate = itemsDelegate
        self.itemsDataSource = itemsDataSource
        deferredConfiguration = configuration
        
        pagingDataSource = GalleryPagingDataSource(
            itemsDataSource: itemsDataSource,
            displacedViewsDataSource: displacedViewsDataSource,
            scrubber: scrubber, configuration: configuration
        )
        super.init(
            transitionStyle: UIPageViewController.TransitionStyle.scroll,
            navigationOrientation: UIPageViewController.NavigationOrientation
                .horizontal,
            options: [
                UIPageViewController.OptionsKey.interPageSpacing: NSNumber(
                    value: spineDividerWidth as Float
                ),
            ]
        )
        pagingDataSource.itemControllerDelegate = self
        /// This feels out of place, one would expect even the first
        /// presented(paged) item controller to be provided by the paging
        /// dataSource but there is nothing we can do as Apple requires the
        /// first controller to be set via this "setViewControllers" method.
        let initialController = pagingDataSource.createItemController(
            startIndex,
            isInitial: true
        )
        setViewControllers(
            [initialController],
            direction: UIPageViewController.NavigationDirection.forward,
            animated: false, completion: nil
        )
        if let controller = initialController as? ItemController {
            initialItemController = controller
        }
        /// This less known/used presentation style option allows the contents
        /// of parent view controller presenting the gallery to "bleed through"
        /// the blurView. Otherwise we would see only black color.
        modalPresentationStyle = .overFullScreen
        dataSource = pagingDataSource
        UIApplication.applicationWindow.windowLevel =
            statusBarHidden ? UIWindow.Level.statusBar + 1 : UIWindow.Level
                .normal
        NotificationCenter.default.addObserver(
            self, selector: #selector(GalleryViewController.rotate),
            name: UIDevice.orientationDidChangeNotification, object: nil
        )
        if continueNextVideoOnFinish {
            NotificationCenter.default.addObserver(
                self, selector: #selector(didEndPlaying),
                name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                object: nil
            )
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }
    
    /// Process configuration items - called lazily in viewDidLoad for better performance
    private func processConfiguration() {
        guard !configurationProcessed else { return }
        configurationProcessed = true
        
        /// Only those options relevant to the paging GalleryViewController are
        /// explicitly handled here, the rest is handled by ItemViewControllers
        for item in deferredConfiguration {
            switch item {
            case let .imageDividerWidth(width): spineDividerWidth = Float(width)
            case let .pagingMode(mode): galleryPagingMode = mode
            case let .headerViewLayout(layout): headerLayout = layout
            case let .footerViewLayout(layout): footerLayout = layout
            case let .closeLayout(layout): closeLayout = layout
            case let .deleteLayout(layout): deleteLayout = layout
            case let .thumbnailsLayout(layout): thumbnailsLayout = layout
            case let .statusBarHidden(hidden): statusBarHidden = hidden
            case let .hideDecorationViewsOnLaunch(hidden): decorationViewsHidden =
                hidden
            case let .decorationViewsFadeDuration(duration): decorationViewsFadeDuration =
                duration
            case let .rotationDuration(duration): rotationDuration = duration
            case let .rotationMode(mode): rotationMode = mode
            case let .overlayColor(color): overlayView.overlayColor = color
            case let .overlayColorOpacity(opacity): overlayView
                .colorTargetOpacity = opacity
            case let .colorPresentDuration(duration): overlayView
                .colorPresentDuration = duration
            case let .colorPresentDelay(delay): overlayView
                .colorPresentDelay = delay
            case let .colorDismissDuration(duration): overlayView
                .colorDismissDuration = duration
            case let .colorDismissDelay(delay): overlayView
                .colorDismissDelay = delay
            case let .continuePlayVideoOnEnd(enabled): continueNextVideoOnFinish =
                enabled
            case let .seeAllCloseLayout(layout): seeAllCloseLayout = layout
            case let .videoControlsColor(color): scrubber.tintColor = color
            case let .displacementDuration(duration): displacementDuration =
                duration
            case let .headerViewVisible(mode): headerViewVisibilityMode = mode
            case let .footerViewVisible(mode): footerViewVisibilityMode = mode
            case let .closeButtonMode(buttonMode):
                switch buttonMode {
                case .none: closeButton = nil
                case let .custom(button): closeButton = button
                case .builtIn: break
                }
            case let .seeAllCloseButtonMode(buttonMode):
                switch buttonMode {
                case .none: seeAllCloseButton = nil
                case let .custom(button): seeAllCloseButton = button
                case .builtIn: break
                }
            case let .thumbnailsButtonMode(buttonMode):
                switch buttonMode {
                case .none: thumbnailsButton = nil
                case let .custom(button): thumbnailsButton = button
                case .builtIn: break
                }
            case let .deleteButtonMode(buttonMode):
                switch buttonMode {
                case .none: deleteButton = nil
                case let .custom(button): deleteButton = button
                case .builtIn: break
                }
            default: break
            }
        }
        
        if continueNextVideoOnFinish {
            NotificationCenter.default.addObserver(
                self, selector: #selector(didEndPlaying),
                name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                object: nil
            )
        }
    }
    @objc func didEndPlaying() { page(toIndex: currentIndex + 1) }
    fileprivate func configureOverlayView() {
        overlayView.bounds.size =
            UIScreen.main.bounds.insetBy(
                dx: -UIScreen.main.bounds.width / 2,
                dy: -UIScreen.main.bounds.height / 2
            ).size
        overlayView.center = CGPoint(
            x: UIScreen.main.bounds.width / 2,
            y: UIScreen.main.bounds.height / 2
        )
        view.addSubview(overlayView)
        view.sendSubviewToBack(overlayView)
    }

    fileprivate func configureHeaderView() {
        if let header = headerView, headerViewVisibilityMode == .visible {
            header.alpha = 0
            view.addSubview(header)
        }
    }

    fileprivate func configureFooterView() {
        if let footer = footerView, footerViewVisibilityMode == .visible {
            footer.alpha = 0
            view.addSubview(footer)
        }
    }

    fileprivate func configureCloseButton() {
        if let closeButton {
            closeButton.addTarget(
                self,
                action: #selector(GalleryViewController.closeInteractively),
                for: .touchUpInside
            )
            closeButton.alpha = 0
            view.addSubview(closeButton)
        }
    }

    fileprivate func configureThumbnailsButton() {
        if let thumbnailsButton {
            thumbnailsButton.addTarget(
                self, action: #selector(GalleryViewController.showThumbnails),
                for: .touchUpInside
            )
            thumbnailsButton.alpha = 0
            view.addSubview(thumbnailsButton)
        }
    }

    fileprivate func configureDeleteButton() {
        if let deleteButton {
            deleteButton.addTarget(
                self, action: #selector(GalleryViewController.deleteItem),
                for: .touchUpInside
            )
            deleteButton.alpha = 0
            view.addSubview(deleteButton)
        }
    }

    fileprivate func configureScrubber() {
        scrubber.alpha = 0
        view.addSubview(scrubber)
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // Process configuration lazily for better performance
        processConfiguration()
        
        if #available(iOS 11.0, *) {
            if statusBarHidden || UIScreen.hasNotch {
                additionalSafeAreaInsets = UIEdgeInsets(
                    top: -20,
                    left: 0,
                    bottom: 0,
                    right: 0
                )
            }
        }
        configureHeaderView()
        configureFooterView()
        configureCloseButton()
        configureThumbnailsButton()
        configureDeleteButton()
        configureScrubber()
        view.clipsToBounds = false
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard initialPresentationDone == false else { return }
        /// We have to call this here (not sooner), because it adds the overlay
        /// view to the presenting controller and the presentingController
        /// property is set only at this moment in the VC lifecycle.
        configureOverlayView()
        /// The initial presentation animations and transitions
        presentInitially()
        initialPresentationDone = true
    }

    fileprivate func presentInitially() {
        isAnimating = true
        /// Animates decoration views to the initial state if they are set to be
        /// visible on launch. We do not need to do anything if they are set to
        /// be hidden because they are already set up as hidden by default.
        /// Unhiding them for the launch is part of chosen UX.
        initialItemController?.presentItem(
            alongsideAnimation: { [weak self] in
                self?.overlayView.present()
                if self?
                    .decorationViewsHidden ==
                    false { self?.animateDecorationViews(visible: true) }
            },
            completion: { [weak self] in
                guard let self else { return }
                isAnimating = false
                launchedCompletion?()
            }
        )
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if rotationMode == .always, UIApplication.isPortraitOnly {
            let transform = windowRotationTransform()
            let bounds = rotationAdjustedBounds()
            view.transform = transform
            view.bounds = bounds
        }
        overlayView.frame = view.bounds.insetBy(
            dx: -UIScreen.main.bounds.width * 2,
            dy: -UIScreen.main.bounds.height * 2
        )
        layoutButton(closeButton, layout: closeLayout)
        layoutButton(thumbnailsButton, layout: thumbnailsLayout)
        layoutButton(deleteButton, layout: deleteLayout)
        layoutHeaderView()
        layoutFooterView()
        layoutScrubber()
    }

    private var defaultInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            view.safeAreaInsets
        } else {
            UIEdgeInsets(
                top: statusBarHidden ? 0.0 : 20.0,
                left: 0.0,
                bottom: 0.0,
                right: 0.0
            )
        }
    }

    fileprivate func layoutButton(_ button: UIButton?, layout: ButtonLayout) {
        guard let button else { return }
        switch layout {
        case let .pinRight(marginTop, marginRight):
            button.autoresizingMask = [
                .flexibleBottomMargin,
                .flexibleLeftMargin,
            ]
            button.frame.origin.x = view.bounds.size
                .width - marginRight - button.bounds.size.width
            button.frame.origin.y = defaultInsets.top + marginTop
        case let .pinLeft(marginTop, marginLeft):
            button.autoresizingMask = [
                .flexibleBottomMargin,
                .flexibleRightMargin,
            ]
            button.frame.origin.x = marginLeft
            button.frame.origin.y = defaultInsets.top + marginTop
        }
    }

    fileprivate func layoutHeaderView() {
        guard let header = headerView else { return }
        switch headerLayout {
        case let .center(marginTop):
            header.autoresizingMask = [
                .flexibleBottomMargin,
                .flexibleLeftMargin,
                .flexibleRightMargin,
            ]
            header.center = view.boundsCenter
            header.frame.origin.y = defaultInsets.top + marginTop
        case let .pinBoth(marginTop, marginLeft, marginRight):
            header.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth]
            header.bounds.size.width = view.bounds
                .width - marginLeft - marginRight
            header.sizeToFit()
            header.frame.origin = CGPoint(
                x: marginLeft,
                y: defaultInsets.top + marginTop
            )
        case let .pinLeft(marginTop, marginLeft):
            header.autoresizingMask = [
                .flexibleBottomMargin,
                .flexibleRightMargin,
            ]
            header.frame.origin = CGPoint(
                x: marginLeft,
                y: defaultInsets.top + marginTop
            )
        case let .pinRight(marginTop, marginRight):
            header.autoresizingMask = [
                .flexibleBottomMargin,
                .flexibleLeftMargin,
            ]
            header.frame.origin = CGPoint(
                x: view.bounds.width - marginRight - header.bounds.width,
                y: defaultInsets.top + marginTop
            )
        }
    }

    fileprivate func layoutFooterView() {
        guard let footer = footerView else { return }
        switch footerLayout {
        case let .center(marginBottom):
            footer.autoresizingMask = [
                .flexibleTopMargin,
                .flexibleLeftMargin,
                .flexibleRightMargin,
            ]
            footer.center = view.boundsCenter
            footer.frame.origin.y =
                view.bounds.height - footer.bounds
                    .height - marginBottom - defaultInsets.bottom
        case let .pinBoth(marginBottom, marginLeft, marginRight):
            footer.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
            footer.frame.size.width = view.bounds
                .width - marginLeft - marginRight
            footer.sizeToFit()
            footer.frame.origin = CGPoint(
                x: marginLeft,
                y: view.bounds.height - footer.bounds
                    .height - marginBottom - defaultInsets.bottom
            )
        case let .pinLeft(marginBottom, marginLeft):
            footer.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
            footer.frame.origin = CGPoint(
                x: marginLeft,
                y: view.bounds.height - footer.bounds
                    .height - marginBottom - defaultInsets.bottom
            )
        case let .pinRight(marginBottom, marginRight):
            footer.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
            footer.frame.origin = CGPoint(
                x: view.bounds.width - marginRight - footer.bounds.width,
                y: view.bounds.height - footer.bounds
                    .height - marginBottom - defaultInsets.bottom
            )
        }
    }

    fileprivate func layoutScrubber() {
        scrubber.bounds = CGRect(
            origin: CGPoint.zero, size: CGSize(
                width: view.bounds.width,
                height: 40
            )
        )
        scrubber.center = view.boundsCenter
        scrubber.frame.origin.y =
            (footerView?.frame.origin.y ?? view.bounds.maxY) - scrubber.bounds
                .height
    }

    @objc fileprivate func deleteItem() {
        deleteButton?.isEnabled = false
        view.isUserInteractionEnabled = false
        itemsDelegate?.removeGalleryItem(at: currentIndex)
        removePage(atIndex: currentIndex) { [weak self] in
            self?.deleteButton?.isEnabled = true
            self?.view.isUserInteractionEnabled = true
        }
    }

    // ThumbnailsimageBlock
    @objc fileprivate func showThumbnails() {
        let thumbnailsController =
            ThumbnailsViewController(itemsDataSource: itemsDataSource)
        if let closeButton = seeAllCloseButton {
            thumbnailsController.closeButton = closeButton
            thumbnailsController.closeLayout = seeAllCloseLayout
        } else if let closeButton {
            let seeAllCloseButton = UIButton(
                frame: CGRect(
                    origin: CGPoint.zero,
                    size: closeButton.bounds.size
                )
            )
            seeAllCloseButton.setImage(
                closeButton.image(for: UIControl.State()),
                for: UIControl.State()
            )
            seeAllCloseButton.setImage(
                closeButton.image(for: .highlighted),
                for: .highlighted
            )
            thumbnailsController.closeButton = seeAllCloseButton
            thumbnailsController.closeLayout = closeLayout
        }
        thumbnailsController
            .onItemSelected = { [weak self] index in
                self?.page(toIndex: index)
            }
        present(thumbnailsController, animated: true, completion: nil)
    }

    open func page(toIndex index: Int) {
        guard currentIndex != index, index >= 0,
              index < itemsDataSource.itemCount()
        else {
            return
        }
        let imageViewController = pagingDataSource.createItemController(index)
        let direction: UIPageViewController.NavigationDirection =
            index > currentIndex ? .forward : .reverse
        // workaround to make UIPageViewController happy
        if direction == .forward {
            let previousVC = pagingDataSource.createItemController(index - 1)
            setViewControllers(
                [previousVC], direction: direction, animated: true,
                completion: { _ in
                    DispatchQueue.main.async { [weak self] in
                        self?.setViewControllers(
                            [imageViewController], direction: direction,
                            animated: false, completion: nil
                        )
                    }
                }
            )
        } else {
            let nextVC = pagingDataSource.createItemController(index + 1)
            setViewControllers(
                [nextVC], direction: direction, animated: true,
                completion: { _ in
                    DispatchQueue.main.async { [weak self] in
                        self?.setViewControllers(
                            [imageViewController], direction: direction,
                            animated: false, completion: nil
                        )
                    }
                }
            )
        }
    }

    func removePage(atIndex index: Int, completion: @escaping () -> Void) {
        // If removing last item, go back, otherwise, go forward
        let direction: UIPageViewController.NavigationDirection =
            index < itemsDataSource.itemCount() ? .forward : .reverse
        let newIndex = direction == .forward ? index : index - 1
        if newIndex < 0 {
            close()
            return
        }
        let vc = pagingDataSource.createItemController(newIndex)
        setViewControllers([vc], direction: direction, animated: true) { _ in
            completion()
        }
    }

    open func reload(atIndex index: Int) {
        guard index >= 0, index < itemsDataSource.itemCount() else { return }
        guard let firstVC = viewControllers?.first,
              let itemController = firstVC as? ItemController
        else { return }
        itemController.fetchImage()
    }

    // MARK: - Animations

    @objc fileprivate func rotate() {
        /// If the app supports rotation on global level, we don't need to
        /// rotate here manually because the rotation
        /// of key Window will rotate all app's content with it via affine
        /// transform and from the perspective of the
        /// gallery it is just a simple relayout. Allowing access to remaining
        /// code only makes sense if the app is
        /// portrait only but we still want to support rotation inside the
        /// gallery.
        guard UIApplication.isPortraitOnly else { return }
        guard UIDevice.current.orientation.isFlat == false,
              isAnimating == false else { return }
        isAnimating = true
        UIView.animate(
            withDuration: rotationDuration, delay: 0,
            options: UIView.AnimationOptions.curveLinear,
            animations: { [weak self] () in
                self?.view.transform = windowRotationTransform()
                self?.view.bounds = rotationAdjustedBounds()
                self?.view.setNeedsLayout()
                self?.view.layoutIfNeeded()
            }
        ) { [weak self] _ in self?.isAnimating = false }
    }

    /// Invoked when closed programmatically
    open func close() { closeDecorationViews(programmaticallyClosedCompletion) }
    /// Invoked when closed via close button
    @objc fileprivate func closeInteractively() {
        closeDecorationViews(closedCompletion)
    }

    fileprivate func closeDecorationViews(_ completion: (() -> Void)?) {
        guard isAnimating == false else { return }
        isAnimating = true
        if let itemController = viewControllers?.first as? ItemController {
            itemController.closeDecorationViews(decorationViewsFadeDuration)
        }
        UIView.animate(
            withDuration: decorationViewsFadeDuration, delay: 0,
            options: [
                .beginFromCurrentState,
                .curveEaseInOut,
                .allowAnimatedContent,
            ],
            animations: { [weak self] in
                if self?.headerViewVisibilityMode == .visible {
                    self?.headerView?.alpha = 0.0
                }
                if self?.footerViewVisibilityMode == .visible {
                    self?.footerView?.alpha = 0.0
                }
                self?.closeButton?.alpha = 0.0
                self?.thumbnailsButton?.alpha = 0.0
                self?.deleteButton?.alpha = 0.0
                self?.scrubber.alpha = 0.0
            },
            completion: { [weak self] _ in
                guard let self,
                      let itemController = viewControllers?
                      .first as? ItemController
                else {
                    return
                }
                itemController.dismissItem(
                    alongsideAnimation: {},
                    completion: { [weak self] in
                        self?.isAnimating = true
                        self?.closeGallery(false, completion: completion)
                    }
                )
            }
        )
    }

    func closeGallery(_ animated: Bool, completion: (() -> Void)?) {
        overlayView.removeFromSuperview()
        modalTransitionStyle = .crossDissolve
        dismiss(animated: animated) {
            UIApplication.applicationWindow.windowLevel = UIWindow.Level.normal
            completion?()
        }
    }

    fileprivate func animateDecorationViews(visible: Bool) {
        let targetAlpha: CGFloat = visible ? 1 : 0
        UIView.animate(
            withDuration: decorationViewsFadeDuration, delay: 0,
            usingSpringWithDamping: 0.95,
            initialSpringVelocity: 0.0, options: [.beginFromCurrentState],
            animations: { [weak self] in
                if self?.headerViewVisibilityMode == .visible {
                    self?.headerView?.alpha = targetAlpha
                }
                if self?.footerViewVisibilityMode == .visible {
                    self?.footerView?.alpha = targetAlpha
                }
                self?.closeButton?.alpha = targetAlpha
                self?.thumbnailsButton?.alpha = targetAlpha
                self?.deleteButton?.alpha = targetAlpha
                if self?.viewControllers?.first as? VideoViewController != nil {
                    UIView.animate(
                        withDuration: 0.3,
                        animations: { [weak self] in
                            self?.scrubber.alpha = targetAlpha
                        }
                    )
                }
            }
        )
    }

    public func itemControllerWillAppear(_ controller: ItemController) {
        if let videoController = controller as? VideoViewController {
            scrubber.player = videoController.player
        }
    }

    public func itemControllerWillDisappear(_ controller: ItemController) {
        if controller as? VideoViewController != nil {
            scrubber.player = nil
            UIView.animate(
                withDuration: 0.3,
                animations: { [weak self] in self?.scrubber.alpha = 0 }
            )
        }
    }

    public func itemControllerDidAppear(_ controller: ItemController) {
        currentIndex = controller.index
        landedPageAtIndexCompletion?(currentIndex)
        headerView?.sizeToFit()
        footerView?.sizeToFit()
        if let videoController = controller as? VideoViewController {
            scrubber.player = videoController.player
            if scrubber.alpha == 0, decorationViewsHidden == false {
                UIView.animate(
                    withDuration: 0.3,
                    animations: { [weak self] in self?.scrubber.alpha = 1 }
                )
            }
        }
    }

    open func itemControllerDidSingleTap(_: ItemController) {
        decorationViewsHidden.flip()
        animateDecorationViews(visible: !decorationViewsHidden)
    }

    open func itemControllerDidLongPress(
        _ controller: ItemController,
        in item: ItemView
    ) {
        switch (controller, item) {
        case (_ as ImageViewController, let item as UIImageView):
            guard let image = item.image else { return }
            let activityVC = UIActivityViewController(
                activityItems: [image],
                applicationActivities: nil
            )
            present(activityVC, animated: true)
        case (_ as VideoViewController, let item as VideoView):
            guard let videoUrl =
                ((item.player?.currentItem?.asset) as? AVURLAsset)?.url
            else { return }
            let activityVC = UIActivityViewController(
                activityItems: [videoUrl], applicationActivities: nil
            )
            present(activityVC, animated: true)
        default: return
        }
    }

    public func itemController(
        _: ItemController,
        finishInteractiveTransitionWithSpingVelocity _: CGFloat,
        duration _: TimeInterval
    ) {}
    public func itemController(
        _ controller: ItemController,
        didSwipeToDismissWithDistanceToEdge distance: CGFloat
    ) {
        if decorationViewsHidden == false {
            let alpha = 1 - distance * swipeToDismissFadeOutAccelerationFactor
            closeButton?.alpha = alpha
            thumbnailsButton?.alpha = alpha
            deleteButton?.alpha = alpha
            if headerViewVisibilityMode == .visible {
                headerView?.alpha = alpha
            }
            if footerViewVisibilityMode == .visible {
                footerView?.alpha = alpha
            }
            if controller is VideoViewController { scrubber.alpha = alpha }
        }
        overlayView.colorView.alpha = 1 - distance
    }

    public func itemControllerDidFinishSwipeToDismissSuccessfully() {
        swipedToDismissCompletion?()
        overlayView.removeFromSuperview()
        dismiss(animated: false, completion: nil)
    }

    public func itemControllerDismissAlongsideAnimation(_: any ItemController)
        -> () ->
        Void
    { { self.overlayView.dismiss() } }
}
