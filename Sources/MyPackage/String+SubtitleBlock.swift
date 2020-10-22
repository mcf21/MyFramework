//
//  String+SubtitleBlock.swift
//  NarrativeText
//
//  Created by Marcel McFall on 30/9/20.
//

import Foundation
extension String {
	var groupRegexStr: String {
		return "(\\d+)\\n([\\d:,.]+)\\s+-{2}\\>\\s+([\\d:,.]+)\\n([\\s\\S]*?(?=\\n{2,}|$))"
	}
	var toFromRegexStr: String {
		return "\\d{1,2}:\\d{1,2}:\\d{1,2}[,.]\\d{1,3}"
	}
	var newLineReturnNewline: String {
		return "\n\r\n"
	}
	var tripleNewLines: String {
		return "\n\n\n"
	}
	var doubleNewLine: String {
		return "\n\n"
	}
	var newLine: String {
		return "\n"
	}
	var returnNewLine: String {
		return "\r\n"
	}
	var indexBlock: String {
		return "^[0-9]+"
	}
	var defaultMatchCount: Int {
		return 2
	}
	func parseIntoSubtitleBlocks() -> [SubtitleBlock] {
		do {

			// Prepare payload
			var payload = self.replacingOccurrences(of: newLineReturnNewline, with: doubleNewLine)
			payload = self.replacingOccurrences(of: tripleNewLines, with: doubleNewLine)
			payload = self.replacingOccurrences(of: returnNewLine, with: newLine)

			// Parsed blocks
			var blocks: [SubtitleBlock] = []

			// Get groups
			let regexStr = groupRegexStr
			let regex = try NSRegularExpression(pattern: regexStr, options: .caseInsensitive)
			let matches = regex.matches(in: payload, options: NSRegularExpression.MatchingOptions(rawValue: .zero), range: NSMakeRange(.zero, payload.count))
			for m in matches {

				let group = (payload as NSString).substring(with: m.range)

				// Get index
				var regex = try NSRegularExpression(pattern: indexBlock, options: .caseInsensitive)
				var match = regex.matches(in: group, options: NSRegularExpression.MatchingOptions(rawValue: .zero), range: NSMakeRange(.zero, group.count))
				guard let i = match.first else {
					continue
				}
				let index = (group as NSString).substring(with: i.range)
				guard let numericIndex = UInt(index) else { continue }

				// Get "from" & "to" time
				regex = try NSRegularExpression(pattern: toFromRegexStr, options: .caseInsensitive)
				match = regex.matches(in: group, options: NSRegularExpression.MatchingOptions(rawValue: .zero), range: NSMakeRange(.zero, group.count))
				guard match.count == defaultMatchCount else {
					continue
				}
				guard let from = match.first, let to = match.last else {
					continue
				}

				var h: TimeInterval = .zero, m: TimeInterval = .zero, s: TimeInterval = .zero, c: TimeInterval = .zero

				let fromStr = (group as NSString).substring(with: from.range)
				var scanner = Scanner(string: fromStr)
				scanner.scanDouble(&h)
				scanner.scanString(":", into: nil)
				scanner.scanDouble(&m)
				scanner.scanString(":", into: nil)
				scanner.scanDouble(&s)
				scanner.scanString(",", into: nil)
				scanner.scanDouble(&c)
				let fromTime = (h * 3600.0) + (m * 60.0) + s + (c / 1000.0)

				let toStr = (group as NSString).substring(with: to.range)
				scanner = Scanner(string: toStr)
				scanner.scanDouble(&h)
				scanner.scanString(":", into: nil)
				scanner.scanDouble(&m)
				scanner.scanString(":", into: nil)
				scanner.scanDouble(&s)
				scanner.scanString(",", into: nil)
				scanner.scanDouble(&c)
				let toTime = (h * 3600.0) + (m * 60.0) + s + (c / 1000.0)

				// Get text & check if empty
				let range = NSMakeRange(.zero, to.range.location + to.range.length + 1)
				guard (group as NSString).length - range.length > .zero else {
					continue
				}
				let text = (group as NSString).replacingCharacters(in: range, with: "")

				// Create final object
				blocks.append(SubtitleBlock(index: numericIndex, startTime: fromTime, endTime: toTime, text: text))
			}
			return blocks   //This is implicitly ordered by the SRT spec
		} catch {

			return []

		}
	}
}
