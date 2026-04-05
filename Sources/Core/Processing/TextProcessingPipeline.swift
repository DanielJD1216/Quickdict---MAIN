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
    static func process(_ text: String) -> String {
        var result = text

        result = normalizeNumbers(result)
        result = normalizeCurrency(result)
        result = normalizeDates(result)
        result = normalizePercentages(result)

        return result
    }

    private static func normalizeNumbers(_ text: String) -> String {
        let numberWords = [
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
            "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
            "seventeen", "eighteen", "nineteen", "twenty", "thirty", "forty", "fifty",
            "sixty", "seventy", "eighty", "ninety", "hundred", "thousand", "million"
        ]

        var result = text
        let pattern = numberWords.joined(separator: "|")

        guard let regex = try? NSRegularExpression(pattern: "\\b(\(pattern))\\b", options: .caseInsensitive) else {
            return result
        }

        let range = NSRange(result.startIndex..., in: result)
        result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "[number]")

        return result
    }

    private static func normalizeCurrency(_ text: String) -> String {
        var result = text

        let currencyPatterns: [(pattern: String, replacement: String)] = [
            ("\\bdollars?\\b", "$"),
            ("\\bcents?\\b", "¢")
        ]

        for (pattern, replacement) in currencyPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
            }
        }

        return result
    }

    private static func normalizeDates(_ text: String) -> String {
        return text
    }

    private static func normalizePercentages(_ text: String) -> String {
        var result = text

        if let regex = try? NSRegularExpression(pattern: "\\b(\\w+)\\s*percent\\b", options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1%")
        }

        return result
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
        "bullet", "next bullet", "new bullet", "bullet point"
    ]

    static func process(_ text: String) -> String {
        var result = text
        let lowercased = text.lowercased()

        for trigger in bulletTriggers {
            if lowercased.contains(trigger) {
                result = result.replacingOccurrences(of: trigger, with: "•", options: .caseInsensitive)
            }
        }

        return result
    }
}
