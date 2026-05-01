import Foundation

enum PayrollLocalization {
    static var locale: Locale {
        if let preferredIdentifier = Bundle.main.preferredLocalizations.first {
            return Locale(identifier: preferredIdentifier)
        }

        return .autoupdatingCurrent
    }

    static var languageCode: String {
        locale.language.languageCode?.identifier ?? locale.identifier
    }

    static func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        safelyFormat(text(key), arguments: arguments)
    }

    static func countLabel(_ count: Int) -> String {
        format("%lld件", Int64(count))
    }

    static func dayLabel(_ day: Int) -> String {
        format("%lld日", Int64(day))
    }

    private static func safelyFormat(_ template: String, arguments: [CVarArg]) -> String {
        var result = ""
        var index = template.startIndex
        var nextArgumentIndex = 0

        while index < template.endIndex {
            guard template[index] == "%" else {
                result.append(template[index])
                template.formIndex(after: &index)
                continue
            }

            let tokenStart = index
            template.formIndex(after: &index)

            guard index < template.endIndex else {
                result.append("%")
                break
            }

            if template[index] == "%" {
                result.append("%")
                template.formIndex(after: &index)
                continue
            }

            var positionalArgumentIndex: Int?
            var digits = ""
            while index < template.endIndex,
                  template[index].isNumber {
                digits.append(template[index])
                template.formIndex(after: &index)
            }

            if index < template.endIndex,
               template[index] == "$" {
                if let position = Int(digits),
                   position > 0 {
                    positionalArgumentIndex = position - 1
                }
                template.formIndex(after: &index)
            }

            while index < template.endIndex,
                  !isSupportedConversionCharacter(template[index]) {
                template.formIndex(after: &index)
            }

            guard index < template.endIndex else {
                result.append(contentsOf: template[tokenStart..<index])
                break
            }

            let conversionCharacter = template[index]
            template.formIndex(after: &index)

            let argumentIndex: Int
            if let positionalArgumentIndex {
                argumentIndex = positionalArgumentIndex
            } else {
                argumentIndex = nextArgumentIndex
                nextArgumentIndex += 1
            }

            guard arguments.indices.contains(argumentIndex) else {
                result.append(contentsOf: template[tokenStart..<index])
                continue
            }

            result.append(argumentText(arguments[argumentIndex], conversionCharacter: conversionCharacter))
        }

        return result
    }

    private static func isSupportedConversionCharacter(_ character: Character) -> Bool {
        character == "@" || "diuoxXfFeEgGaAcCsSp".contains(character)
    }

    private static func argumentText(
        _ argument: CVarArg,
        conversionCharacter: Character
    ) -> String {
        switch conversionCharacter {
        case "d", "i", "u", "o", "x", "X":
            return integerArgumentText(argument)
        case "f", "F", "e", "E", "g", "G", "a", "A":
            return floatingPointArgumentText(argument)
        default:
            return objectArgumentText(argument)
        }
    }

    private static func objectArgumentText(_ argument: CVarArg) -> String {
        if let value = argument as? String {
            return value
        }

        if let value = argument as? CustomStringConvertible {
            return value.description
        }

        return String(describing: argument)
    }

    private static func integerArgumentText(_ argument: CVarArg) -> String {
        switch argument {
        case let value as Int:
            return String(value)
        case let value as Int8:
            return String(value)
        case let value as Int16:
            return String(value)
        case let value as Int32:
            return String(value)
        case let value as Int64:
            return String(value)
        case let value as UInt:
            return String(value)
        case let value as UInt8:
            return String(value)
        case let value as UInt16:
            return String(value)
        case let value as UInt32:
            return String(value)
        case let value as UInt64:
            return String(value)
        default:
            return objectArgumentText(argument)
        }
    }

    private static func floatingPointArgumentText(_ argument: CVarArg) -> String {
        switch argument {
        case let value as Double:
            return String(value)
        case let value as Float:
            return String(value)
        case let value as CGFloat:
            return String(Double(value))
        default:
            return objectArgumentText(argument)
        }
    }

    static func monthLabel(_ month: Int, abbreviated: Bool = false) -> String {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2000
        components.month = month
        components.day = 1

        guard let date = components.date else {
            return String(month)
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate(abbreviated ? "MMM" : "MMMM")
        return formatter.string(from: date)
    }

    static func yearLabel(_ year: Int) -> String {
        switch languageCode {
        case let code where code.hasPrefix("ja"):
            return "\(year)年"
        default:
            return String(year)
        }
    }

    static func recordTitle(year: Int, month: Int, kindTitle: String) -> String {
        switch languageCode {
        case let code where code.hasPrefix("ja"):
            return "\(year)年\(month)月 \(kindTitle)"
        default:
            return "\(kindTitle) \(year)/\(month)"
        }
    }
}
