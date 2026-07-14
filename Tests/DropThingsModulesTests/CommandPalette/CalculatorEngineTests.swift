import XCTest
@testable import DropThingsModules

final class CalculatorEngineTests: XCTestCase {
    private let engine = CalculatorEngine(locale: Locale(identifier: "en_US"))

    func testPrecedenceParenthesesUnaryAndPower() throws {
        XCTAssertEqual(try engine.evaluate("2 + 3 * 4").value, 14)
        XCTAssertEqual(try engine.evaluate("(2 + 3) * 4").value, 20)
        XCTAssertEqual(try engine.evaluate("-2^2").value, -4)
        XCTAssertEqual(try engine.evaluate("2^3^2").value, 512)
    }

    func testFunctionsAndConstants() throws {
        XCTAssertEqual(try engine.evaluate("sqrt(9) + abs(-2)").value, 5)
        XCTAssertEqual(try engine.evaluate("max(1, 4, 2)").value, 4)
        XCTAssertEqual(try engine.evaluate("round(pi)").value, 3)
    }

    func testDivisionByZeroAndNonFiniteAreTypedErrors() {
        XCTAssertThrowsError(try engine.evaluate("1 / 0")) { XCTAssertEqual($0 as? CalculatorError, .divisionByZero) }
        XCTAssertThrowsError(try engine.evaluate("sqrt(-1)")) { XCTAssertEqual($0 as? CalculatorError, .nonFiniteResult) }
    }

    func testArbitraryCodeIsRejected() {
        XCTAssertThrowsError(try engine.evaluate("Process()"))
        XCTAssertNil(engine.resultIfCalculation("hello world"))
    }

    func testCommaDecimalLocale() throws {
        let spanish = CalculatorEngine(locale: Locale(identifier: "es_AR"))
        XCTAssertEqual(try spanish.evaluate("1,5 + 2").value, 3.5)
    }

    func testDeterministicFuzzInputsNeverCrashOrReturnNonFiniteValues() {
        var generator = CalculatorFuzzGenerator(seed: 0xC0FFEE)
        let alphabet = Array("0123456789+-*/%^()., abcdefgilmnoprstuq")
        for _ in 0..<2_000 {
            let length = Int(generator.next() % 48)
            let input = String((0..<length).map { _ in alphabet[Int(generator.next() % UInt64(alphabet.count))] })
            if let value = try? engine.evaluate(input).value {
                XCTAssertTrue(value.isFinite, "Non-finite result for \(input)")
            }
        }
    }
}

private struct CalculatorFuzzGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return state
    }
}
