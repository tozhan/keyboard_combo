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

    func testUnknownKeyFallsBackToNumericName() {
        XCTAssertEqual(KeyCatalog.displayName(for: 500), "Key 500")
    }
}
