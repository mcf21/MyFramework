//
//  BasicNarrativeViewModel.swift
//  NarrativeText
//
//  Created by Marcel McFall on 16/10/20.
//

import Foundation
import AVFoundation

public final class BasicNarrativeViewModel {
	public weak var subtitleDelegate: SubtitleDelegate?
	let subtitles: Subtitles
	var player: AVPlayer
	
	public init(player: AVPlayer, withSubtitle subtitles: Subtitles) {
		self.player = player
		self.subtitles = subtitles
		addPeriodicNotification()
	}
	
	func addPeriodicNotification() {
		// Add periodic notifications
		player.addPeriodicTimeObserver(
			forInterval: CMTimeMake(value: 1, timescale: 60),
			queue: DispatchQueue.main,
			using: { [weak self] (time) -> Void in
				// Search && show subtitles
				guard let text =  self?.subtitles.searchSubtitles(at: time.seconds) else { return }
				self?.subtitleDelegate?.showText(text.text)
		})
	}
}
