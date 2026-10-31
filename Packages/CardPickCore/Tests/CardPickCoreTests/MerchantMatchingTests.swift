import XCTest
import CardPickCore

final class MerchantMatchingTests: XCTestCase {
    func testWholeNameAndPhrase() {
        XCTAssertTrue(MerchantMatching.matches(placeName: "Lyft", merchant: "Lyft"))
        XCTAssertTrue(MerchantMatching.matches(placeName: "lyft hub", merchant: "Lyft"))
        XCTAssertTrue(MerchantMatching.matches(placeName: "Chase Travel℠", merchant: "Chase Travel"))
        XCTAssertTrue(MerchantMatching.matches(placeName: "Peloton NYC", merchant: "Peloton"))
        XCTAssertFalse(MerchantMatching.matches(placeName: "Flyft", merchant: "Lyft"))
        XCTAssertFalse(MerchantMatching.matches(placeName: "Alyft Store", merchant: "Lyft"))
        XCTAssertFalse(MerchantMatching.matches(placeName: "Shell", merchant: "Lyft"))
    }
}
