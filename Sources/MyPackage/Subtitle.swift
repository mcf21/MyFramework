//
//  Subtitle.swift
//  NarrativeText
//
//  Created by Marcel McFall on 30/9/20.
//

import Foundation

@objc public class Subtitles: NSObject {

	// MARK: - Properties
	let blocks: [SubtitleBlock] // Ordered by startTime ascending. Increased access here to allow this to drive the subtitles UI interactions

	// MARK: - Public methods
	public init?(file filePath: URL, encoding: String.Encoding = String.Encoding.utf8) {
		do {
			let string = try String(contentsOf: filePath, encoding: encoding)
			blocks = Subtitles.parseSubRip(string)
		} catch {
			return nil
		}
	}

	/// Search subtitle on time
	///
	/// - Parameters:
	///   - payload: Inout payload
	///   - time: Time
	/// - Returns: String
	// This method assumes that there is one or fewer subtitles at any point in time. This is probably fine for stockmans, but doesn't hold in general for SRT subtitles.
	@objc class func searchSubtitles(_ payload: [SubtitleBlock], _ time: TimeInterval) -> SubtitleBlock? {
		#warning("TODO: These subtitles were trimmed of whitespace and newlines -- probably need to update this at the view model. text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)")
		
		return payload.filter({$0.startTime <= time && $0.endTime >= time}).first
	}

	@objc public init(subtitles string: String) {
		blocks = Subtitles.parseSubRip(string)
	}

	/// Search subtitles at time
	///
	/// - Parameter time: Time
	/// - Returns: String if exists
	func searchSubtitles(at time: TimeInterval) -> SubtitleBlock? {
		return Subtitles.searchSubtitles(blocks, time)
	}

	// MARK: - Private methods

	/// Subtitle parser
	///
	/// - Parameter payload: Input string
	/// - Returns: NSDictionary
	@objc class func parseSubRip(_ payload: String) -> [SubtitleBlock] {
		do {

			// Prepare payload
			var payload = payload.replacingOccurrences(of: "\n\r\n", with: "\n\n")
			payload = payload.replacingOccurrences(of: "\n\n\n", with: "\n\n")
			payload = payload.replacingOccurrences(of: "\r\n", with: "\n")

			// Parsed blocks
			var blocks: [SubtitleBlock] = []

			// Get groups
			let regexStr = "(\\d+)\\n([\\d:,.]+)\\s+-{2}\\>\\s+([\\d:,.]+)\\n([\\s\\S]*?(?=\\n{2,}|$))"
			let regex = try NSRegularExpression(pattern: regexStr, options: .caseInsensitive)
			let matches = regex.matches(in: payload, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, payload.count))
			for m in matches {

				let group = (payload as NSString).substring(with: m.range)

				// Get index
				var regex = try NSRegularExpression(pattern: "^[0-9]+", options: .caseInsensitive)
				var match = regex.matches(in: group, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, group.count))
				guard let i = match.first else {
					continue
				}
				let index = (group as NSString).substring(with: i.range)
				guard let numericIndex = UInt(index) else { continue }

				// Get "from" & "to" time
				regex = try NSRegularExpression(pattern: "\\d{1,2}:\\d{1,2}:\\d{1,2}[,.]\\d{1,3}", options: .caseInsensitive)
				match = regex.matches(in: group, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, group.count))
				guard match.count == 2 else {
					continue
				}
				guard let from = match.first, let to = match.last else {
					continue
				}

				var h: TimeInterval = 0.0, m: TimeInterval = 0.0, s: TimeInterval = 0.0, c: TimeInterval = 0.0

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
				let range = NSMakeRange(0, to.range.location + to.range.length + 1)
				guard (group as NSString).length - range.length > 0 else {
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
