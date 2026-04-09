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
passed = expect(BulletFormatter.process("bullet bananas next bullet peanuts next bullet apples") == "• Bananas\n• Peanuts\n• Apples", "bullet formatter should split spoken bullet triggers") && passed
passed = expect(BulletFormatter.process("1 bananas 2 peanuts 3 apples") == "• Bananas\n• Peanuts\n• Apples", "bullet formatter should convert numbered list patterns") && passed
passed = expect(BulletFormatter.process("I'm gonna go to the grocery store to get some bananas, peanuts, apples, potatoes.") == "• Bananas\n• Peanuts\n• Apples\n• Potatoes", "bullet formatter should convert shopping sentences") && passed
passed = expect(BulletFormatter.process("I need to do workout also homework also finalize the contract") == "• Workout\n• Homework\n• Finalize the contract", "bullet formatter should split spoken todo separators") && passed
passed = expect(BulletFormatter.process("lista de compras leche, huevos, pan") == "• Leche\n• Huevos\n• Pan", "bullet formatter should support multilingual list cues") && passed

if passed {
    print("All processing checks passed.")
    exit(0)
} else {
    exit(1)
}
