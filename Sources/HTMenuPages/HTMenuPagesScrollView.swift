//
//  HTMenuPages.swift
//
//  Created by Nansen on 2025/6/18.
//

import Foundation
import UIKit


public class HTMenuScrollView: UIScrollView, UIGestureRecognizerDelegate {
    
    var navigation: UINavigationController? {
        didSet {
            if let naviVC = navigation, let popG = naviVC.interactivePopGestureRecognizer, let arr = gestureRecognizers, arr.isEmpty == false {
                for gesture in arr {
                    gesture.require(toFail: popG)
                }
            }
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard let otherView = otherGestureRecognizer.view, String(describing: otherView.classForCoder) == "UITableViewWrapperView", otherGestureRecognizer is UIPanGestureRecognizer else {
            return false
        }
        
        return true
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }
        
        let velocity = panGesture.velocity(in: self)
        let location = gestureRecognizer.location(in: self)
        
        if abs(velocity.y) > abs(velocity.x) {
            return false
        }
        
        let screenW: CGFloat = UIScreen.main.bounds.width
        if velocity.x > 0 && Int(location.x) % Int(screenW) < 30 {
            // 向右滑动, 开始于整个屏幕左侧边缘30内, 预估用户是想要右划返回功能
            return false
        }
        
        return true
    }
    
}


