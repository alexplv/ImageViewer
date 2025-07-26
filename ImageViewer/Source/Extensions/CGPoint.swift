//
//  CGPoint.swift
//  ImageViewer
//
//  Created by Michael Brown on 08/12/2015.
//  Copyright © 2015 MailOnline. All rights reserved.
//
import CoreGraphics

extension CGPoint { func inverted() -> CGPoint { return CGPoint(x: y, y: x) } }
enum Direction { case left, right, up, down, none }
enum Orientation { case vertical, horizontal, none }
/// Movement can be expressed as a vector in 2D coordinate space where the implied unit is 1 second and the vector point from 0,0 to an actual CGPoint value represents direction and speed. Then we can calculate convenient properties describing the nature of movement.
extension CGPoint {
    var direction: Direction {
        guard !(x == 0 && y == 0) else { return .none }
        if abs(x) > abs(y) && x > 0 {
            return .right
        } else if abs(x) > abs(y) && x <= 0 {
            return .left
        } else if abs(x) <= abs(y) && y > 0 {
            return .up
        } else if abs(x) <= abs(y) && y <= 0 {
            return .down
        } else {
            return .none
        }
    }

    var orientation: Orientation {
        guard direction != .none else { return .none }
        if direction == .left || direction == .right {
            return .horizontal
        } else {
            return .vertical
        }
    }
}
