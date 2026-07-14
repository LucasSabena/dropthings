import Foundation

public enum CalculatorError: Error, Equatable, LocalizedError, Sendable {
    case invalidExpression
    case unexpectedToken
    case divisionByZero
    case unknownIdentifier(String)
    case wrongArgumentCount(String)
    case nonFiniteResult

    public var errorDescription: String? {
        switch self {
        case .invalidExpression: return "Invalid calculation."
        case .unexpectedToken: return "Unexpected token in calculation."
        case .divisionByZero: return "Division by zero."
        case .unknownIdentifier(let name): return "Unknown function or constant: \(name)."
        case .wrongArgumentCount(let name): return "Wrong number of arguments for \(name)."
        case .nonFiniteResult: return "The calculation is outside the supported range."
        }
    }
}

public struct CalculatorValue: Equatable, Sendable {
    public let expression: String
    public let value: Double
    public let formatted: String
}

public struct CalculatorEngine: Sendable {
    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    public func evaluate(_ expression: String) throws -> CalculatorValue {
        let normalized = normalizeDecimalSeparator(expression)
        var parser = try Parser(source: normalized)
        let value = try parser.parse()
        guard value.isFinite else { throw CalculatorError.nonFiniteResult }
        return CalculatorValue(expression: expression, value: value, formatted: format(value))
    }

    public func resultIfCalculation(_ expression: String) -> CalculatorValue? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.rangeOfCharacter(from: .decimalDigits) != nil || ["pi", "e"].contains(trimmed.lowercased()) else { return nil }
        return try? evaluate(trimmed)
    }

    private func normalizeDecimalSeparator(_ input: String) -> String {
        guard locale.decimalSeparator == "," else { return input }
        return input.replacingOccurrences(of: ",", with: ".")
    }

    private func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 12
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .halfEven
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

private struct Parser {
    private enum Token: Equatable {
        case number(Double), identifier(String), plus, minus, multiply, divide, modulo, power
        case leftParen, rightParen, comma, end
    }

    private var tokens: [Token]
    private var index = 0

    init(source: String) throws {
        self.tokens = try Lexer(source: source).tokens() + [.end]
    }

    mutating func parse() throws -> Double {
        guard tokens != [.end] else { throw CalculatorError.invalidExpression }
        let value = try expression()
        guard current == .end else { throw CalculatorError.unexpectedToken }
        return try finite(value)
    }

    private var current: Token { tokens[index] }
    private mutating func advance() { index += 1 }

    private mutating func expression() throws -> Double {
        var value = try term()
        while true {
            switch current {
            case .plus: advance(); value += try term()
            case .minus: advance(); value -= try term()
            default: return try finite(value)
            }
        }
    }

    private mutating func term() throws -> Double {
        var value = try unary()
        while true {
            switch current {
            case .multiply: advance(); value *= try unary()
            case .divide:
                advance(); let divisor = try unary()
                guard divisor != 0 else { throw CalculatorError.divisionByZero }
                value /= divisor
            case .modulo:
                advance(); let divisor = try unary()
                guard divisor != 0 else { throw CalculatorError.divisionByZero }
                value.formTruncatingRemainder(dividingBy: divisor)
            default: return try finite(value)
            }
        }
    }

    private mutating func unary() throws -> Double {
        switch current {
        case .plus: advance(); return try unary()
        case .minus: advance(); return -(try unary())
        default: return try power()
        }
    }

    private mutating func power() throws -> Double {
        var value = try primary()
        if current == .power {
            advance()
            value = Foundation.pow(value, try unary())
        }
        return try finite(value)
    }

    private mutating func primary() throws -> Double {
        switch current {
        case .number(let value): advance(); return value
        case .identifier(let name):
            advance()
            if current == .leftParen { return try function(name) }
            switch name { case "pi": return .pi; case "e": return M_E; default: throw CalculatorError.unknownIdentifier(name) }
        case .leftParen:
            advance(); let value = try expression()
            guard current == .rightParen else { throw CalculatorError.unexpectedToken }
            advance(); return value
        default: throw CalculatorError.unexpectedToken
        }
    }

    private mutating func function(_ name: String) throws -> Double {
        advance()
        var arguments: [Double] = []
        if current != .rightParen {
            arguments.append(try expression())
            while current == .comma { advance(); arguments.append(try expression()) }
        }
        guard current == .rightParen else { throw CalculatorError.unexpectedToken }
        advance()
        let value: Double
        switch (name, arguments.count) {
        case ("sqrt", 1): value = Foundation.sqrt(arguments[0])
        case ("abs", 1): value = Swift.abs(arguments[0])
        case ("round", 1): value = arguments[0].rounded()
        case ("floor", 1): value = Foundation.floor(arguments[0])
        case ("ceil", 1): value = Foundation.ceil(arguments[0])
        case ("min", let count) where count >= 1: value = arguments.min()!
        case ("max", let count) where count >= 1: value = arguments.max()!
        case ("sqrt", _), ("abs", _), ("round", _), ("floor", _), ("ceil", _), ("min", _), ("max", _):
            throw CalculatorError.wrongArgumentCount(name)
        default: throw CalculatorError.unknownIdentifier(name)
        }
        return try finite(value)
    }

    private func finite(_ value: Double) throws -> Double {
        guard value.isFinite else { throw CalculatorError.nonFiniteResult }
        return value
    }

    private struct Lexer {
        let source: String

        func tokens() throws -> [Token] {
            var output: [Token] = []
            var index = source.startIndex
            while index < source.endIndex {
                let character = source[index]
                if character.isWhitespace { index = source.index(after: index); continue }
                if character.isNumber || character == "." {
                    let start = index
                    var dots = 0
                    while index < source.endIndex {
                        let current = source[index]
                        guard current.isNumber || current == "." else { break }
                        if current == "." { dots += 1 }
                        index = source.index(after: index)
                    }
                    guard dots <= 1, let value = Double(source[start..<index]) else { throw CalculatorError.invalidExpression }
                    output.append(.number(value)); continue
                }
                if character.isLetter {
                    let start = index
                    while index < source.endIndex, source[index].isLetter { index = source.index(after: index) }
                    output.append(.identifier(source[start..<index].lowercased())); continue
                }
                let token: Token
                switch character {
                case "+": token = .plus; case "-": token = .minus; case "*", "×": token = .multiply
                case "/", "÷": token = .divide; case "%": token = .modulo; case "^": token = .power
                case "(": token = .leftParen; case ")": token = .rightParen; case ",": token = .comma
                default: throw CalculatorError.unexpectedToken
                }
                output.append(token); index = source.index(after: index)
            }
            return output
        }
    }
}
