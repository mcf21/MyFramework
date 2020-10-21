//
//  ScrollingSubtitlesViewModel.swift
//  NarrativeText
//
//  Created by Marcel McFall on 30/9/20.
//

import Foundation
import AVFoundation

public protocol ScrollingSubtitlesViewModelDelegate: AnyObject {
	func scrollingSubtitlesViewModel(_ viewModel: ScrollingSubtitlesViewModel, shouldShowSubtitleBlock subtitleBlock: SubtitleBlock)
	func scrollingSubtitlesViewModel(_ viewModel: ScrollingSubtitlesViewModel, shouldDismissSubtitleBlock subtitleBlock: SubtitleBlock)
	func scrollingSubtitlesViewModel(_ viewModel: ScrollingSubtitlesViewModel, didSeekToSubtitleBlock subtitleBock: SubtitleBlock)
}

public class ScrollingSubtitlesViewModel {

	
	public var subtitles: Subtitles?
	public var player: AVPlayer?
	weak var delegate: ScrollingSubtitlesViewModelDelegate?
	var currentSubtitleBlock: SubtitleBlock?
	var previousSubtitleBlock: SubtitleBlock? // The most recently dismissed subtitle block. Nil if none have been dismissed yet
	var previousPlaybackTime: TimeInterval = 0  // Used to determine whether a skip has occurred. Should be refactored

	public init(player: AVPlayer, subtitles: Subtitles) {
		self.player = player
		self.subtitles = subtitles
	}

	public func triggerSubtitles() {
		guard let player = player else { return }
		addPeriodicNotification(forPlayer: player)
	}
	
	func addPeriodicNotification(forPlayer player: AVPlayer) {
		// Add periodic notifications
		player.addPeriodicTimeObserver(
			forInterval: CMTimeMake(value: 1, timescale: 1000),
			queue: nil,
			using: { [weak self](time) -> Void in
				guard let strongSelf = self else { return }
				// Search && show subtitles
				let newSubtitleBlock = strongSelf.subtitles?.searchSubtitles(at: time.seconds)
				let oldSubtitleBlock = strongSelf.currentSubtitleBlock
				let timeDifference = abs(CMTimeGetSeconds(time) - strongSelf.previousPlaybackTime)
				let didSeek = timeDifference > 0.5  // This isn't great -- needs to be refactored
				let subtitleBlockHasntChanged = newSubtitleBlock == oldSubtitleBlock
				strongSelf.previousPlaybackTime = CMTimeGetSeconds(time)

				// Short circuit
				if subtitleBlockHasntChanged { return }

				let newSubtitleIsEntering = newSubtitleBlock != nil
				let oldSubtitleIsExiting = (oldSubtitleBlock != nil) && (strongSelf.currentSubtitleBlock != newSubtitleBlock)
				strongSelf.currentSubtitleBlock = newSubtitleBlock

				if didSeek {
					//Short circuits
					guard let newSubtitleBlock = newSubtitleBlock else { fatalError("Expected non-nil subtitle block") }
					strongSelf.delegate?.scrollingSubtitlesViewModel(strongSelf, didSeekToSubtitleBlock: newSubtitleBlock)
					return
				}
				if oldSubtitleIsExiting {
					guard let oldSubtitleBlock = oldSubtitleBlock else { fatalError("Expected non-nil subtitle block") }
					strongSelf.previousSubtitleBlock = oldSubtitleBlock
					strongSelf.delegate?.scrollingSubtitlesViewModel(strongSelf, shouldDismissSubtitleBlock: oldSubtitleBlock)
				}
				if newSubtitleIsEntering {
					guard let newSubtitleBlock = newSubtitleBlock else { fatalError("Expected non-nil subtitle block") }
					strongSelf.delegate?.scrollingSubtitlesViewModel(strongSelf, shouldShowSubtitleBlock: newSubtitleBlock)
				}
			}
		)
	}

}
