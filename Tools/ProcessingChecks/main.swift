import Foundation

@discardableResult
func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        return false
    }
    return true
}

var passed = true

passed = expect(FillerWordRemover.process("um hello world") == "hello world", "filler remover should strip leading filler") && passed
passed = expect(FalseStartDetector.process("the the quick brown fox") == "the quick brown fox", "false-start detector should remove repeated lead-in") && passed
passed = expect(InverseTextNormalizer.process("twenty three dollars") == "$23", "ITN should convert spoken currency") && passed
passed = expect(InverseTextNormalizer.process("forty two percent growth") == "42% growth", "ITN should convert percentages") && passed
passed = expect(BulletFormatter.process("bullet bananas next bullet peanuts next bullet apples") == "• bananas\n• peanuts\n• apples", "bullet formatter should split spoken bullet triggers") && passed
passed = expect(BulletFormatter.process("1 bananas 2 peanuts 3 apples") == "• Bananas\n• Peanuts\n• Apples", "bullet formatter should convert numbered list patterns") && passed

if passed {
    print("All processing checks passed.")
    exit(0)
} else {
    exit(1)
}
