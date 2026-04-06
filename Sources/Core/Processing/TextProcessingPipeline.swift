import Foundation

struct TextProcessingPipeline {
    var removeFillers: Bool = true
    var removeFalseStarts: Bool = true
    var numberConversion: Bool = true
    var autoPunctuation: Bool = false
    var bulletPoints: Bool = true

    func process(_ text: String) -> String {
        var result = text

        if removeFillers {
            result = FillerWordRemover.process(result)
        }

        if removeFalseStarts {
            result = FalseStartDetector.process(result)
        }

        if numberConversion {
            result = InverseTextNormalizer.process(result)
        }

        if autoPunctuation {
            result = AutoPunctuation.process(result)
        }

        if bulletPoints {
            result = BulletFormatter.process(result)
        }

        return result
    }
}

struct FillerWordRemover {
    private static let fillerPatterns = [
        "\\bum\\b", "\\buh\\b", "\\blike\\b", "\\byou know\\b",
        "\\bI mean\\b", "\\bso\\b", "\\bwell\\b", "\\bbasically\\b",
        "\\bactually\\b", "\\breally\\b", "\\bjust\\b", "\\bmaybe\\b"
    ]

    static func process(_ text: String) -> String {
        var result = text
        let pattern = fillerPatterns.joined(separator: "|")

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return result
        }

        let range = NSRange(result.startIndex..., in: result)
        result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")

        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.trimmingCharacters(in: .whitespaces)

        return result
    }
}

struct FalseStartDetector {
    static func process(_ text: String) -> String {
        let words = text.split(separator: " ").map(String.init)
        guard words.count > 2 else { return text }

        var result: [String] = []
        var i = 0

        while i < words.count {
            if i + 2 < words.count {
                let current = words[i].lowercased()
                let next = words[i + 1].lowercased()

                if current == next ||
                   (current.hasSuffix(",") && words[i].dropLast().lowercased() == next) {
                    result.append(words[i])
                    i += 2
                    continue
                }

                if isFalseStartPattern(words: words, at: i) {
                    i += 2
                    continue
                }
            }

            result.append(words[i])
            i += 1
        }

        return result.joined(separator: " ")
    }

    private static func isFalseStartPattern(words: [String], at index: Int) -> Bool {
        guard index + 3 < words.count else { return false }

        let phrase1 = words[index].lowercased()
        let phrase2 = words[index + 2].lowercased()

        return phrase1 == phrase2
    }
}

struct InverseTextNormalizer {
    private static let baseNumbers: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
        "nineteen": 19, "twenty": 20, "thirty": 30, "forty": 40,
        "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]
    private static let multipliers: [String: Int] = ["hundred": 100, "thousand": 1000, "million": 1_000_000]
    private static let ignorableWords: Set<String> = ["and"]

    static func process(_ text: String) -> String {
        var result = text

        result = normalizeNumbers(result)
        result = normalizeCurrency(result)
        result = normalizeDates(result)
        result = normalizePercentages(result)

        return result
    }

    private static func normalizeNumbers(_ text: String) -> String {
        let tokens = text.split(separator: " ").map(String.init)
        var output: [String] = []
        var index = 0

        while index < tokens.count {
            if let parsed = parseNumberPhrase(tokens, start: index) {
                output.append(String(parsed.value))
                index += parsed.consumed
            } else {
                output.append(tokens[index])
                index += 1
            }
        }

        return output.joined(separator: " ")
    }

    private static func normalizeCurrency(_ text: String) -> String {
        var result = text
        if let regex = try? NSRegularExpression(pattern: "\\b(\\d+)\\s+dollars?\\b", options: .caseInsensitive) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
            var mutable = nsString
            for match in matches {
                let amount = nsString.substring(with: match.range(at: 1))
                mutable = mutable.replacingCharacters(in: match.range, with: "$\(amount)") as NSString
            }
            result = mutable as String
        }

        if let regex = try? NSRegularExpression(pattern: "\\b(\\d+)\\s+cents?\\b", options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1¢")
        }

        return result
    }

    private static func normalizeDates(_ text: String) -> String {
        return text
    }

    private static func normalizePercentages(_ text: String) -> String {
        var result = text

        if let regex = try? NSRegularExpression(pattern: "\\b(\\d+)\\s*percent\\b", options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1%")
        }

        return result
    }

    private static func parseNumberPhrase(_ tokens: [String], start: Int) -> (value: Int, consumed: Int)? {
        var index = start
        var current = 0
        var total = 0
        var consumed = 0

        while index < tokens.count {
            let cleaned = normalizedToken(tokens[index])
            if cleaned.isEmpty {
                break
            }
            if ignorableWords.contains(cleaned) {
                index += 1
                consumed += 1
                continue
            }
            if let base = baseNumbers[cleaned] {
                current += base
                index += 1
                consumed += 1
                continue
            }
            if let multiplier = multipliers[cleaned] {
                if current == 0 { current = 1 }
                current *= multiplier
                if multiplier >= 1000 {
                    total += current
                    current = 0
                }
                index += 1
                consumed += 1
                continue
            }
            break
        }

        guard consumed > 0 else { return nil }
        return (total + current, consumed)
    }

    private static func normalizedToken(_ token: String) -> String {
        token.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
    }
}

struct AutoPunctuation {
    static func process(_ text: String) -> String {
        var result = text

        result = result.replacingOccurrences(of: " . ", with: ". ")
        result = result.replacingOccurrences(of: " , ", with: ", ")
        result = result.replacingOccurrences(of: " ? ", with: "? ")
        result = result.replacingOccurrences(of: " ! ", with: "! ")

        return result
    }
}

struct BulletFormatter {
    private static let bulletTriggers = [
        "bullet", "next bullet", "new bullet", "bullet point",
        "point", "next point", "new point", "dot point", "dash"
    ]

    private static let explicitListCuePatterns = [
        "shopping list", "grocery list", "to-?do list", "todo list", "checklist",
        "things to buy", "things i need to buy", "things to do", "stuff i need to do",
        "lista de compras", "lista de la compra", "lista del supermercado", "lista de tareas", "lista de pendientes",
        "liste de courses", "liste de taches", "liste de tâches", "choses a acheter", "choses à acheter", "choses a faire", "choses à faire",
        "einkaufsliste", "to-?do-liste", "aufgabenliste",
        "lista do supermercado", "lista de afazeres",
        "lista della spesa", "lista delle cose da fare",
        "boodschappenlijst", "boodschappenlijstje", "to-?do-lijst", "takenlijst"
    ]

    private static let actionListCuePatterns = [
        #"(?:i\s*(?:am|'m)\s+going\s+to\s+do)"#, #"(?:i\s+need\s+to\s+(?:buy|get|do))"#, #"(?:need\s+to\s+(?:buy|get|do))"#,
        #"(?:to\s+)?(?:get|buy|grab|pick up|pickup|need|do)"#,
        #"(?:tengo\s+que\s+(?:comprar|hacer))"#, #"(?:necesito\s+(?:comprar|hacer))"#,
        #"(?:je\s+dois\s+(?:acheter|faire))"#, #"(?:il\s+faut\s+(?:acheter|faire))"#,
        #"(?:ich\s+muss\s+(?:kaufen|erledigen|machen))"#,
        #"(?:preciso\s+(?:comprar|fazer))"#, #"(?:tenho\s+que\s+(?:comprar|fazer))"#,
        #"(?:devo\s+(?:comprare|fare))"#,
        #"(?:ik\s+moet\s+(?:kopen|doen))"#
    ]

    private static let spokenListSeparatorPatterns = [
        #"\b(?:0|zero|oh)\s+(?:also|then|next|plus)\b"#,
        #"\b(?:and then|also|then|plus|next|too)\b"#,
        #"\b(?:también|y luego|después)\b"#,
        #"\b(?:aussi|puis|ensuite)\b"#,
        #"\b(?:auch|dann)\b"#,
        #"\b(?:também|depois)\b"#,
        #"\b(?:anche|poi)\b"#,
        #"\b(?:ook|dan)\b"#
    ]

    static func process(_ text: String) -> String {
        let lowercased = text.lowercased()

        if bulletTriggers.contains(where: { lowercased.contains($0) }) {
            let pattern = "(?i)(?:^|\\s|,)(?:next bullet|new bullet|bullet point|bullet|next point|new point|dot point|point|dash)[:,-]?\\s+"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsRange = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: nsRange)
                guard !matches.isEmpty else { return text }

                var items: [String] = []
                for (index, match) in matches.enumerated() {
                    let itemStart = match.range.upperBound
                    let itemEnd = index + 1 < matches.count ? matches[index + 1].range.location : (text as NSString).length
                    let range = NSRange(location: itemStart, length: itemEnd - itemStart)
                    let item = (text as NSString)
                        .substring(with: range)
                        .replacingOccurrences(of: "^(?:and|then)\\s+", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !item.isEmpty {
                        items.append(contentsOf: expandBulletItem(item).map { "• \(capitalizingFirstLetter($0))" })
                    }
                }
                if !items.isEmpty {
                    return items.joined(separator: "\n")
                }
            }
        }

        let numberedPattern = "(?:^|\\s)(?:\\d+|zero|oh)[\\.\\)]?\\s+(.+?)(?=(?:\\s+(?:\\d+|zero|oh)[\\.\\)]?\\s+)|$)"
        if let regex = try? NSRegularExpression(pattern: numberedPattern) {
            let nsRange = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: nsRange)
            if matches.count >= 2 {
                let firstMatchLocation = matches[0].range.location
                let prefix = (text as NSString).substring(to: firstMatchLocation).trimmingCharacters(in: .whitespacesAndNewlines)
                let items = matches.compactMap { match -> String? in
                    guard match.numberOfRanges >= 2 else { return nil }
                    let item = (text as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !item.isEmpty else { return nil }
                    let cleaned = item.replacingOccurrences(of: "^and\\s+", with: "", options: .regularExpression)
                    guard !cleaned.isEmpty else { return nil }
                    return "• \(cleaned.prefix(1).uppercased())\(cleaned.dropFirst())"
                }
                let listBody = items.joined(separator: "\n")
                return prefix.isEmpty ? listBody : "\(prefix)\n\(listBody)"
            }
        }

        if let markerRange = text.range(of: #"(?i)\b(?:0|zero|oh)[\.\)]?\s+"#, options: .regularExpression) {
            let tail = String(text[markerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let items = expandBulletItem(tail).map { "• \(capitalizingFirstLetter($0))" }
            if items.count >= 2 {
                return items.joined(separator: "\n")
            }
        }

        if let tail = extractTail(for: explicitListCuePatterns, in: text) {
            let items = expandBulletItem(tail).map { "• \(capitalizingFirstLetter($0))" }
            if items.count >= 2 {
                return items.joined(separator: "\n")
            }
        }

        if let tail = extractTail(for: actionListCuePatterns, in: text) {
            let items = expandBulletItem(tail).map { "• \(capitalizingFirstLetter($0))" }
            if items.count >= 2 {
                return items.joined(separator: "\n")
            }
        }

        return text
    }

    private static func capitalizingFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private static func expandBulletItem(_ text: String) -> [String] {
        let cleaned = normalizeListFragment(text)
        let normalizedSeparators = normalizeSpokenListSeparators(cleaned)
        let fragments = normalizedSeparators
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { normalizeListFragment(String($0)) }
            .filter { !$0.isEmpty }

        guard fragments.count > 1 else {
            return cleaned.isEmpty ? [] : [cleaned]
        }

        let firstFragmentHadSingularArticle = text.range(of: "^(?:get|buy|grab|pick up|pickup|need)\\s+(?:a|an)\\s+", options: .regularExpression) != nil ||
            text.range(of: "^(?:a|an)\\s+", options: .regularExpression) != nil

        return fragments.map { fragment in
            guard firstFragmentHadSingularArticle else { return fragment }
            return pluralizeSingleWord(fragment)
        }
    }

    private static func normalizeListFragment(_ text: String) -> String {
        text
            .replacingOccurrences(of: "^(?:(?:i\\s*(?:am|'m)\\s+going\\s+to\\s+do)|(?:i\\s+need\\s+to\\s+(?:buy|get|do))|(?:need\\s+to\\s+(?:buy|get|do))|(?:to\\s+)?(?:get|buy|grab|pick up|pickup|need|do)|(?:tengo\\s+que\\s+(?:comprar|hacer))|(?:necesito\\s+(?:comprar|hacer))|(?:je\\s+dois\\s+(?:acheter|faire))|(?:il\\s+faut\\s+(?:acheter|faire))|(?:ich\\s+muss\\s+(?:kaufen|erledigen|machen))|(?:preciso\\s+(?:comprar|fazer))|(?:tenho\\s+que\\s+(?:comprar|fazer))|(?:devo\\s+(?:comprare|fare))|(?:ik\\s+moet\\s+(?:kopen|doen)))\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^(?:and|and then|also|then|plus|next|too)\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "^(?:some|a|an|the)\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+(?:0|zero|oh)$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func extractTail(for cuePatterns: [String], in text: String) -> String? {
        let pattern = "(?i)\\b(?:\(cuePatterns.joined(separator: "|")))\\b[:\\s,-]+(.+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange), match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeSpokenListSeparators(_ text: String) -> String {
        spokenListSeparatorPatterns.reduce(text) { partialResult, pattern in
            partialResult.replacingOccurrences(of: pattern, with: ", ", options: .regularExpression)
        }
    }

    private static func pluralizeSingleWord(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return trimmed }

        let lowercased = trimmed.lowercased()
        if lowercased.hasSuffix("s") {
            return trimmed
        }
        if lowercased.hasSuffix("y"), lowercased.count > 1 {
            let vowelBeforeY = ["a", "e", "i", "o", "u"].contains(String(lowercased.dropLast().suffix(1)))
            if !vowelBeforeY {
                return String(trimmed.dropLast()) + "ies"
            }
        }
        if lowercased.hasSuffix("ch") || lowercased.hasSuffix("sh") || lowercased.hasSuffix("x") || lowercased.hasSuffix("z") {
            return trimmed + "es"
        }
        return trimmed + "s"
    }
}
