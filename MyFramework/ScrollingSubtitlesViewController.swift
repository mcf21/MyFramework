//
//  ScrollingSubtitlesViewController.swift
//  NarrativeText
//
//  Created by Marcel McFall on 30/9/20.
//

import UIKit
import AVFoundation

//This needs to be refactored before it can be put into a Framework.  (i.e. using Apple's Combine Framework.)
public class ScrollingSubtitlesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

	enum ScrollInteractionMode {
		case automatic  // Only the current subtitle is shown on screen. Subtitles are updated in place automatically as they are hit
		case manual     // User has scrolled recently. All subtitles are shown, and aren't updated automatically
	}

	@IBOutlet var narrativeTextScrubbingCollectionView: UICollectionView!
	@IBOutlet var narrativeTextScrubbingCollectionViewFlowLayout: UICollectionViewFlowLayout!

	public var player: AVPlayer?
	var timer = Timer()
	public var viewModel: ScrollingSubtitlesViewModel?
	let songName: String = "Scobie"
	let songExtension: String = "mov"
	let interactionModeMaxIdleTime: TimeInterval = 3

	var cellHeights: [CGFloat] = [] // Cell heights are cached for automatic scrolling. Indexed by indexPath.item
	var lastScrollTime = Date.distantPast
	var scrollViewIsBeingDragged = false
	var scrollInteractionTimer: Timer!  // Move this to an initialiser
	var scrollInteractionMode = ScrollInteractionMode.automatic

	public override func viewDidLoad() {
		super.viewDidLoad()
		viewModel?.delegate = self

		configureCollectionView()

		if #available(iOS 10.0, *) {
			timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] timer in
				self?.updateScrollInteractionState()
			}
		} else {
			// Fallback on earlier versions
		}
		RunLoop.main.add(timer, forMode: .common)
	}

	func configureCollectionView() {
		narrativeTextScrubbingCollectionView.register(UINib.init(nibName: String(describing: SubtitleCollectionViewCell.self), bundle: nibBundle), forCellWithReuseIdentifier: String(describing: SubtitleCollectionViewCell.self))
		if #available(iOS 10.0, *) {
			narrativeTextScrubbingCollectionViewFlowLayout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
		} else {
			//
		}
	}

	public override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		guard let player = player else { return }

		viewModel?.triggerSubtitles()
		player.play()
		narrativeTextScrubbingCollectionView.reloadData()
	}

	public override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		updateCachedCellHeights()
	}

	func transitionToAutomaticMode() {
		scrollInteractionMode = .automatic

		// Transition to automatic mode: Animate the current cell back to the top, and hide the other cells
		if let block = viewModel?.previousSubtitleBlock {
			// If a subtitle block has already been displayed, then animate out all cells that aren't currently playing, while scrolling to the current visible cell
			narrativeTextScrubbingCollectionView.visibleCells.forEach { cell in
				guard let cell = cell as? SubtitleCollectionViewCell else { fatalError() }
				let hidden = block != cell.block
				cell.configure(hidden: hidden, featured: false, block: cell.block, animated: true)

				guard let index = viewModel?.subtitles?.blocks.firstIndex(of: block) else { fatalError() }
				let yPos = yPositionForCell(at: index)
				UIView.animate(withDuration: 0.3) {
					self.narrativeTextScrubbingCollectionView.contentOffset = CGPoint(x: 0, y: yPos)
				} completion: { _ in
					//Make sure that the current cell is visible no matter what
					if let currentBlock = self.viewModel?.currentSubtitleBlock,
					   let activeCell = self.narrativeTextScrubbingCollectionView.visibleCells.first(where: { ($0 as! SubtitleCollectionViewCell).block == currentBlock}) as? SubtitleCollectionViewCell,
					   let index = self.viewModel?.subtitles?.blocks.firstIndex(of: currentBlock){
						self.narrativeTextScrubbingCollectionView.visibleCells.forEach { cell in
							guard let cell = cell as? SubtitleCollectionViewCell else { return }
							let visible = cell === activeCell
							cell.textLabel.alpha = visible ? 1 : 0   //This is bad lol. Refactor
						}
						activeCell.configure(hidden: false, featured: true, block: currentBlock, animated: false)
						let yPos = self.yPositionForCell(at: index)
						// Scroll to the cell that corresponds to the appropriate block, based on it's calculated position
						self.narrativeTextScrubbingCollectionView.contentOffset = CGPoint(x: 0, y: yPos)
					} else {
						self.narrativeTextScrubbingCollectionView.visibleCells.forEach { cell in
							guard let cell = cell as? SubtitleCollectionViewCell else { return }
							cell.textLabel.alpha = 0
						}
					}
				}
			}
		} else {
			// If a subtitle block hasn't been displayed yet, just refresh the collectionview
			narrativeTextScrubbingCollectionView.reloadData()
		}
	}

	func transitionToManualMode() {
		scrollInteractionMode = .manual

		// Transition to manual mode: Make all cells visible. Autoscrolling will be disabled
		narrativeTextScrubbingCollectionView.visibleCells.forEach { ($0 as! SubtitleCollectionViewCell).configure(hidden: false, featured: false, block: ($0 as! SubtitleCollectionViewCell).block, animated: true) }
	}
	
	@IBAction private func closedTapped(_ sender: Any) {
		player?.pause()
		dismiss(animated: true, completion: nil)
	}
	
	@IBAction private func pauseTapped(_ sender: Any) {
		player?.pause()
	}
	
	@IBAction private func restartTapped(_ sender: Any) {
		player?.play()
	}
	
	func updateCachedCellHeights() {
		cellHeights = viewModel?.subtitles?.blocks.map({ heightOfCell(withText: $0.text) }) ?? []
	}

	// Returns the height of a cell with a multiline label for given text. Cells are layed out using autolayout; this method is used solely to assist in calculating the content offset for a given subtitle
	func heightOfCell(withText text: String) -> CGFloat {
		let cellWidth = view.frame.size.width
		let labelSpacingX = SubtitleCollectionViewCell.textLabelHorizontalSpacing
		let labelWidth = cellWidth - 2*labelSpacingX
		let labelSpacingY = SubtitleCollectionViewCell.textLabelVerticalSpacing
		let cellAdditionalYInsets: CGFloat = 2*labelSpacingY

		let font = UIFont.boldSystemFont(ofSize: 28)
		let attributes = [NSAttributedString.Key.font: font]
		let sizingString = NSAttributedString.init(string: text, attributes: attributes)

		// Allow the text to span as many lines as required
		let boundingRectMaxSize = CGSize(width: labelWidth, height: CGFloat.greatestFiniteMagnitude)
		let options: NSStringDrawingOptions = [.usesLineFragmentOrigin]

		return sizingString.boundingRect(with: boundingRectMaxSize, options: options, context: nil).height + cellAdditionalYInsets
	}

	// Returns the y position for a cell, taking into account insets, previous cells, and inter-cell spacing. Does not take into account section headers etc. Cells are layed out using autolayout; this method is used solely to assist in calculating the appropriate content offset for a given subtitle
	func yPositionForCell(at index: Int) -> CGFloat {
		assert(index < cellHeights.count, "yPositionForCell attempted to unwrap an out of bounds cell")

		let yCellSpacing = narrativeTextScrubbingCollectionViewFlowLayout.minimumLineSpacing

		var cumulativeHeightOfPreviousCells: CGFloat = 0
		for i in 0..<index {
			cumulativeHeightOfPreviousCells += cellHeights[Int(i)]
		}

		let index = CGFloat(index)
		return cumulativeHeightOfPreviousCells + index*yCellSpacing
	}

	// Called regularly to determine whether scrolling & subtitle display should happen `automatic`ally (driven by the audio file) or `manual`ly (driven by the user dragging the scroll view)
	func updateScrollInteractionState() {
		let scrolledInTheLastThreeSeconds = Date() < lastScrollTime + interactionModeMaxIdleTime

		// If the last scrollTime was more than three seconds ago and we are manually scrolling, go back to autoscroll
		if scrolledInTheLastThreeSeconds == false && scrollInteractionMode == .manual {
			transitionToAutomaticMode()
		}

		// If the last scrollTime was less than three seconds ago and we are automatically scrolling, go to manual mode
		if scrolledInTheLastThreeSeconds && scrollInteractionMode == .automatic {
			transitionToManualMode()
		}
	}

	// MARK: - UICollectionViewDataSource
	public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { viewModel?.subtitles?.blocks.count ?? 0 }

	public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: SubtitleCollectionViewCell.self), for: indexPath) as? SubtitleCollectionViewCell else { fatalError("Couldn't dequeue NarrativeTextCollectionViewCell") }
		guard let block = viewModel?.subtitles?.blocks[indexPath.item] else { fatalError() }

		cell.textLabel.text = block.text
		let labelSpacingX = SubtitleCollectionViewCell.textLabelHorizontalSpacing
		cell.textLabel.preferredMaxLayoutWidth = narrativeTextScrubbingCollectionView.frame.width - 2*labelSpacingX
		cell.widthConstraint.constant = self.narrativeTextScrubbingCollectionView.frame.size.width

		let hidden = scrollInteractionMode == .automatic
		cell.configure(hidden: hidden, featured: false, block: block, animated: false)

		return cell
	}


	// MARK: - UICollectionViewDelegate

	public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		if scrollInteractionMode != .manual { return }

		guard let block = self.viewModel?.subtitles?.blocks[indexPath.item] else { return }

		let seekTime = CMTime(seconds: block.startTime, preferredTimescale: 1000)

		self.scrollInteractionMode = .automatic
		lastScrollTime = Date.distantPast

		self.player?.seek(to: seekTime, completionHandler: { _ in
			self.player?.play() // Resume plackback if it had already reached the end
		})
	}

	// MARK: - UIScrollViewDelegate

	// The following delegate methods determine whether the user is scrolling the collection view. If they are, update the last scroll on each interaction. Manual mode is entered on the first scroll event, and ends three seconds after the last scroll event

	public func scrollViewDidScroll(_ scrollView: UIScrollView) {
		if scrollViewIsBeingDragged == false { return }

		lastScrollTime = Date()
	}

	public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
		scrollViewIsBeingDragged = true
		lastScrollTime = Date()
		updateScrollInteractionState()
	}

	public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		scrollViewIsBeingDragged = false
		lastScrollTime = Date()
	}

}
extension ScrollingSubtitlesViewController: ScrollingSubtitlesViewModelDelegate {

	// Automatically displays the next subtitle block when it's start timecode is reached
	public func scrollingSubtitlesViewModel(_ viewModel: ScrollingSubtitlesViewModel, shouldShowSubtitleBlock subtitleBlock: SubtitleBlock) {
		// Short circut if in manual scroll mode
		if scrollInteractionMode == .manual { return }

		guard let index = viewModel.subtitles?.blocks.firstIndex(of: subtitleBlock) else { fatalError() }
		let yPos = yPositionForCell(at: index)
		UIView.animate(withDuration: 0.3) {
			// Scroll to the cell that corresponds to the appropriate block, based on it's calculated position
			self.narrativeTextScrubbingCollectionView.contentOffset = CGPoint(x: 0, y: yPos)
		}
		guard let cell = narrativeTextScrubbingCollectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? SubtitleCollectionViewCell else { return }
		// Make the cell visible
		cell.configure(hidden: false, featured: true, block: subtitleBlock, animated: true)
	}

	// Automatically dismisses the current subtitle block when it's end timecode is reached
	public func scrollingSubtitlesViewModel(_ viewModel: ScrollingSubtitlesViewModel, shouldDismissSubtitleBlock subtitleBlock: SubtitleBlock) {
		// Short circut if in manual scroll mode
		if scrollInteractionMode == .manual { return }

		guard let index = viewModel.subtitles?.blocks.firstIndex(of: subtitleBlock) else { return }
		guard let cell = narrativeTextScrubbingCollectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? SubtitleCollectionViewCell else { return }
		// Hide the cell
		cell.configure(hidden: true, featured: true, block: subtitleBlock, animated: true)
	}

	public func scrollingSubtitlesViewModel(_ viewModel: ScrollingSubtitlesViewModel, didSeekToSubtitleBlock subtitleBlock: SubtitleBlock) {
		UIView.animate(withDuration: 0.3) {
			self.narrativeTextScrubbingCollectionView.visibleCells.forEach{ ($0 as! SubtitleCollectionViewCell).textLabel.alpha = 0 }
		}

		guard let index = self.viewModel?.subtitles?.blocks.firstIndex(of: subtitleBlock) else { fatalError() }
		let yPos = self.yPositionForCell(at: index)
		UIView.animate(withDuration: 0.3) {
			// Scroll to the cell that corresponds to the appropriate block, based on it's calculated position
			self.narrativeTextScrubbingCollectionView.contentOffset = CGPoint(x: 0, y: yPos)
		} completion: { _ in
			self.narrativeTextScrubbingCollectionView.visibleCells.forEach{ ($0 as! SubtitleCollectionViewCell).textLabel.alpha = 0 }
			guard let cell = self.narrativeTextScrubbingCollectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? SubtitleCollectionViewCell else { return }
			// Make the cell visible
			cell.configure(hidden: false, featured: true, block: subtitleBlock, animated: true)
		}
	}

}
