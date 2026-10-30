import CoreGraphics
import Foundation

struct KeyboardKey: Identifiable, Sendable {
    let keyCode: UInt16
    let fallbackLabel: String
    let width: Double

    var id: UInt16 { keyCode }
}

enum KeyCatalog {
    static let functionKeyGroups: [[KeyboardKey]] = [
        [key(53, "esc", 1.15)],
        [key(122, "F1"), key(120, "F2"), key(99, "F3"), key(118, "F4")],
        [key(96, "F5"), key(97, "F6"), key(98, "F7"), key(100, "F8")],
        [key(101, "F9"), key(109, "F10"), key(103, "F11"), key(111, "F12")],
        [key(105, "F13"), key(107, "F14"), key(113, "F15")],
        [key(106, "F16"), key(64, "F17"), key(79, "F18"), key(80, "F19")]
    ]

    static let rows: [[KeyboardKey]] = [
        [
            key(50, "`"), key(18, "1"), key(19, "2"), key(20, "3"),
            key(21, "4"), key(23, "5"), key(22, "6"), key(26, "7"),
            key(28, "8"), key(25, "9"), key(29, "0"), key(27, "-"),
            key(24, "="), key(51, "delete", 1.6)
        ],
        [
            key(48, "tab", 1.45), key(12, "Q"), key(13, "W"), key(14, "E"),
            key(15, "R"), key(17, "T"), key(16, "Y"), key(32, "U"),
            key(34, "I"), key(31, "O"), key(35, "P"), key(33, "["),
            key(30, "]"), key(42, "\\", 1.3)
        ],
        [
            key(57, "caps", 1.7), key(0, "A"), key(1, "S"), key(2, "D"),
            key(3, "F"), key(5, "G"), key(4, "H"), key(38, "J"),
            key(40, "K"), key(37, "L"), key(41, ";"), key(39, "'"),
            key(36, "return", 1.85)
        ],
        [
            key(56, "⇧", 2.2), key(6, "Z"), key(7, "X"), key(8, "C"),
            key(9, "V"), key(11, "B"), key(45, "N"), key(46, "M"),
            key(43, ","), key(47, "."), key(44, "/"), key(60, "⇧", 2.25)
        ],
        [
            key(63, "fn", 1.1), key(59, "⌃", 1.1), key(58, "⌥", 1.1),
            key(55, "⌘", 1.35), key(49, "space", 5.4), key(54, "⌘", 1.35),
            key(61, "⌥", 1.1), key(62, "⌃", 1.1)
        ]
    ]

    static let navigationRows: [[KeyboardKey]] = [
        [key(114, "help"), key(115, "home"), key(116, "pg↑")],
        [key(117, "⌦"), key(119, "end"), key(121, "pg↓")]
    ]

    static let arrowRows: [[KeyboardKey]] = [
        [key(126, "↑")],
        [key(123, "←"), key(125, "↓"), key(124, "→")]
    ]

    static let numericKeypadTopRows: [[KeyboardKey]] = [
        [key(71, "clear"), key(81, "="), key(75, "/"), key(67, "×")],
        [key(89, "7"), key(91, "8"), key(92, "9"), key(78, "−")],
        [key(86, "4"), key(87, "5"), key(88, "6"), key(69, "+")]
    ]

    static let numericKeypadBottomRows: [[KeyboardKey]] = [
        [key(83, "1"), key(84, "2"), key(85, "3")],
        [key(82, "0", 2.15), key(65, ".")]
    ]

    static let numericKeypadEnter = key(76, "enter")

    static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    static let allKeys: [KeyboardKey] = {
        var keys = functionKeyGroups.flatMap { $0 }
        keys.append(contentsOf: rows.flatMap { $0 })
        keys.append(contentsOf: navigationRows.flatMap { $0 })
        keys.append(contentsOf: arrowRows.flatMap { $0 })
        keys.append(contentsOf: numericKeypadTopRows.flatMap { $0 })
        keys.append(contentsOf: numericKeypadBottomRows.flatMap { $0 })
        keys.append(numericKeypadEnter)
        return keys
    }()

    static func displayName(for keyCode: UInt16) -> String {
        if let cached = catalogDisplayNames[keyCode] {
            return cached
        }

        if let special = specialNames[keyCode] {
            return special
        }

        if let translated = translatedCharacter(for: keyCode) {
            return translated.uppercased()
        }

        return allKeys.first(where: { $0.keyCode == keyCode })?.fallbackLabel
            ?? "Key \(keyCode)"
    }

    private static let catalogDisplayNames: [UInt16: String] = Dictionary(
        uniqueKeysWithValues: allKeys.map { key in
            let name = specialNames[key.keyCode]
                ?? translatedCharacter(for: key.keyCode)?.uppercased()
                ?? key.fallbackLabel
            return (key.keyCode, name)
        }
    )

    private static let specialNames: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
        54: "Right ⌘", 55: "Left ⌘", 56: "Left ⇧", 57: "Caps Lock",
        58: "Left ⌥", 59: "Left ⌃", 60: "Right ⇧", 61: "Right ⌥",
        62: "Right ⌃", 63: "Fn", 64: "F17", 65: "Keypad .",
        67: "Keypad *", 69: "Keypad +", 71: "Keypad Clear",
        75: "Keypad /", 76: "Keypad Enter", 78: "Keypad -",
        79: "F18", 80: "F19", 81: "Keypad =", 82: "Keypad 0",
        83: "Keypad 1", 84: "Keypad 2", 85: "Keypad 3",
        86: "Keypad 4", 87: "Keypad 5", 88: "Keypad 6",
        89: "Keypad 7", 91: "Keypad 8", 92: "Keypad 9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 105: "F13", 107: "F14", 109: "F10",
        106: "F16", 111: "F12", 113: "F15", 114: "Help",
        115: "Home", 116: "Page Up",
        117: "Forward Delete", 118: "F4", 119: "End", 120: "F2",
        121: "Page Down", 122: "F1", 123: "←", 124: "→",
        125: "↓", 126: "↑"
    ]

    private static func key(_ keyCode: UInt16, _ label: String, _ width: Double = 1) -> KeyboardKey {
        KeyboardKey(keyCode: keyCode, fallbackLabel: label, width: width)
    }

    private static func translatedCharacter(for keyCode: UInt16) -> String? {
        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(keyCode),
            keyDown: true
        ) else {
            return nil
        }

        var actualLength = 0
        var characters = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: characters.count,
            actualStringLength: &actualLength,
            unicodeString: &characters
        )

        guard actualLength == 1,
              let scalar = UnicodeScalar(characters[0]),
              !CharacterSet.controlCharacters.contains(scalar)
        else {
            return nil
        }
        return String(Character(scalar))
    }
}
