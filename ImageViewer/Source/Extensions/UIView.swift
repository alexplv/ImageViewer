//
//  UIView.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 29/02/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//
import UIKit

extension UIView {
    public var boundsCenter: CGPoint {
        CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    }

    func frame(inCoordinatesOfView parentView: UIView) -> CGRect {
        let frameInWindow = UIApplication.applicationWindow.convert(
            bounds,
            from: self
        )
        return parentView.convert(
            frameInWindow,
            from: UIApplication.applicationWindow
        )
    }

    func addSubviews(_ subviews: UIView...) {
        for view in subviews {
            addSubview(view)
        }
    }

    static func animateWithDuration(
        _ duration: TimeInterval, delay: TimeInterval,
        animations: @escaping () -> Void
    ) {
        UIView.animate(
            withDuration: duration, delay: delay,
            options: UIView.AnimationOptions(
            ),
            animations: animations, completion: nil
        )
    }

    static func animateWithDuration(
        _ duration: TimeInterval, delay: TimeInterval,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)?
    ) {
        UIView.animate(
            withDuration: duration, delay: delay,
            options: UIView.AnimationOptions(
            ),
            animations: animations, completion: completion
        )
    }
}

extension DisplaceableView {
    func frameInCoordinatesOfScreen() -> CGRect {
        UIView().convert(bounds, to: UIScreen.main.coordinateSpace)
    }
}
