//
//  UIColor.swift
//  ImageViewer
//
//  Created by Ross Butler on 17/02/2017.
//  Copyright © 2017 MailOnline. All rights reserved.
//
import UIKit

extension UIColor {
    open func shadeDarker() -> UIColor {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let variance: CGFloat = 0.4
        let newR = CGFloat.maximum(r * variance, 0.0)
        let newG = CGFloat.maximum(g * variance, 0.0)
        let newB = CGFloat.maximum(b * variance, 0.0)
        return UIColor(red: newR, green: newG, blue: newB, alpha: 1.0)
    }
}
