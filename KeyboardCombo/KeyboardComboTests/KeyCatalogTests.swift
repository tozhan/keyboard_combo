import XCTest
@testable import KeyboardCombo

final class KeyCatalogTests: XCTestCase {
    func testCatalogHasUniquePhysicalKeys() {
        let keyCodes = KeyCatalog.allKeys.map(\.keyCode)
        XCTAssertEqual(Set(keyCodes).count, keyCodes.count)
    }

    func testModifierCatalogIncludesLeftAndRightVariants() {
        XCTAssertTrue(KeyCatalog.modifierKeyCodes.isSuperset(of: [54, 55, 56, 58, 59, 60, 61, 62]))
        XCTAssertEqual(KeyCatalog.displayName(for: 55), "Left ⌘")
        XCTAssertEqual(KeyCatalog.displayName(for: 54), "Right ⌘")
    }

    func testCatalogIncludesFullKeyboardSections() {
        let keyCodes = Set(KeyCatalog.allKeys.map(\.keyCode))

        XCTAssertTrue(keyCodes.isSuperset(of: [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]))
        XCTAssertTrue(keyCodes.isSuperset(of: [114, 115, 116, 117, 119, 121]))
        XCTAssertTrue(keyCodes.isSuperset(of: [65, 67, 69, 71, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92]))
        XCTAssertEqual(KeyCatalog.displayName(for: 80), "F19")
        XCTAssertEqual(KeyCatalog.displayName(for: 83), "Keypad 1")
    }

    func testUnknownKeyFallsBackToNumericName() {
        XCTAssertEqual(KeyCatalog.displayName(for: 500), "Key 500")
    }
}
