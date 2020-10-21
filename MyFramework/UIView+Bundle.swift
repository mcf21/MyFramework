//
//  UIView+Bundle.swift
//  NarrativeText
//
//  Created by Marcel McFall on 16/10/20.
//

import Foundation
import UIKit

extension UIView {
	class func fromNib<T: UIView>() -> T {
		return Bundle.main.loadNibNamed(String(describing: T.self), owner: nil, options: nil)![0] as! T
	}
}

