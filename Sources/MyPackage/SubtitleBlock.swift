//
//  SubtitleBlock.swift
//  NarrativeText
//
//  Created by Marcel McFall on 30/9/20.
//

import Foundation

@objc public class SubtitleBlock: NSObject {
	let index: UInt
	let startTime: TimeInterval
	let endTime: TimeInterval
	let text: String
	
	init(index: UInt, startTime: TimeInterval, endTime: TimeInterval, text: String) {
		self.index = index
		self.startTime = startTime
		self.endTime = endTime
		self.text = text
	}
}
