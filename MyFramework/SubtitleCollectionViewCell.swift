//
//  SubtitleCollectionViewCell.swift
//  NarrativeText
//
//  Created by Marcel McFall on 30/9/20.
//

import UIKit

public class SubtitleCollectionViewCell: UICollectionViewCell {

	@IBOutlet var textLabel: UILabel!
	@IBOutlet var widthConstraint: NSLayoutConstraint!
	@IBOutlet var textLabelLeadingConstraint: NSLayoutConstraint!
	@IBOutlet var textLabelTopConstraint: NSLayoutConstraint!

	static let textLabelHorizontalSpacing: CGFloat = 15    // Distance from the top and bottom of the label to the contentView
	static let textLabelVerticalSpacing: CGFloat = 10  // Distance from the leading and trailing of the label to the contentView
	var block: SubtitleBlock?

	public override func awakeFromNib() {
		super.awakeFromNib()
		textLabelLeadingConstraint.constant = SubtitleCollectionViewCell.textLabelHorizontalSpacing
		textLabelTopConstraint.constant = SubtitleCollectionViewCell.textLabelVerticalSpacing
	}

	func configure(hidden: Bool, featured: Bool, block: SubtitleBlock?, animated: Bool) {
		self.block = block
		let duration = animated ? 0.3 : 0
		UIView.animate(withDuration: duration) {
			self.textLabel.alpha = hidden ? 0 : 1
		}
	}

}

