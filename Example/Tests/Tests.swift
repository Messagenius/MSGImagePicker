import XCTest
@testable import MSGImagePicker

class MSGImagePickerTests: XCTestCase {
    
    func testConfigDefaults() {
        let config = MSGImagePickerConfig()
        XCTAssertEqual(config.maxSelection, 10)
        XCTAssertTrue(config.allowsVideo)
        XCTAssertTrue(config.allowsPhoto)
        XCTAssertTrue(config.showsCaptions)
    }
    
    func testPickedMediaIsEdited() {
        // Test that isEdited returns correct values
        // Note: Full testing requires PHAsset which needs device/simulator
    }
}
