import XCTest
import CardPickCore

final class POICategoryMappingTests: XCTestCase {
    func testMapKitRawValuesAndShortNames() {
        let dining = ["restaurant", "cafe", "bakery", "brewery", "winery", "nightlife", "distillery"]
        for name in dining {
            XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: name), .dining, name)
            XCTAssertEqual(
                POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategory" + name.prefix(1).uppercased() + name.dropFirst()),
                .dining,
                name
            )
        }

        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryRestaurant"), .dining)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryCafe"), .dining)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryBakery"), .dining)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryGasStation"), .gas)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "gasStation"), .gas)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryFoodMarket"), .groceries)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "foodMarket"), .groceries)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryPharmacy"), .drugstore)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryHotel"), .travel)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryAirport"), .travel)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryStore"), .other)
    }

    func testUnknownPlaceIsOther() {
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryMuseum"), .other)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: "MKPOICategoryBowling"), .other)
        XCTAssertEqual(POICategoryMapping.rewardCategory(forPOIRawValue: ""), .other)
        XCTAssertEqual(POICategoryMapping.placeKindName(forPOIRawValue: ""), "Place")
        XCTAssertEqual(POICategoryMapping.placeKindName(forPOIRawValue: "MKPOICategoryMovieTheater"), "Movie Theater")
        XCTAssertEqual(POICategoryMapping.placeKindName(forPOIRawValue: "MKPOICategoryGasStation"), "Gas Station")
        XCTAssertEqual(POICategoryMapping.placeKindName(forPOIRawValue: "MKPOICategoryFoodMarket"), "Grocery")
    }
}
