//
//  BasicNarrativeView.swift
//  NarrativeText
//
//  Created by Marcel McFall on 16/10/20.
//

import UIKit
import AVFoundation

@objc public protocol SubtitleDelegate {
	func showText(_ subtitle: String)
}

public final class BasicNarrativeView: UIView {
	@IBOutlet var narrativeText: UITextView!
	@IBOutlet var actionButton: UIButton!
	var viewModel: BasicNarrativeViewModel?


	// MARK: Initalize functions
	required init(viewModel: BasicNarrativeViewModel) {
		self.viewModel = viewModel
		super.init(frame: CGRect.zero)
	}
	
	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		
	}
	// MARK: - IBAction
	@IBAction private func pauseTapped(_ sender: Any) {
		viewModel?.player.pause()
	}
	
	@IBAction private func restartTapped(_ sender: Any) {
		viewModel?.player.play()
	}
}
extension BasicNarrativeView: SubtitleDelegate {
	public func showText(_ subtitle: String) {
		DispatchQueue.main.async {
			self.narrativeText.text = subtitle
		}
	}
}
