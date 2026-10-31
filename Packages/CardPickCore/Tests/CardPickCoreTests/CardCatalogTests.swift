import XCTest
import CardPickCore

final class CardCatalogTests: XCTestCase {
    func testSeedCards() throws {
        let catalog = try CardCatalog.bundled()
        XCTAssertEqual(catalog.version, 1)
        XCTAssertEqual(catalog.cards.map(\.id), ["robinhood-gold", "chase-sapphire-reserve"])

        let robinhood = try XCTUnwrap(catalog.cards.first { $0.id == "robinhood-gold" })
        XCTAssertEqual(robinhood.name, "Robinhood Gold")
        XCTAssertEqual(robinhood.rewardType, .cashback)
        XCTAssertEqual(robinhood.rules.count, 1)
        XCTAssertEqual(robinhood.rules[0].earn, .cashback(centsPerDollar: 3))
        XCTAssertTrue(robinhood.rules[0].categories.isEmpty)
        XCTAssertTrue(robinhood.rules[0].merchants.isEmpty)

        let reserve = try XCTUnwrap(catalog.cards.first { $0.id == "chase-sapphire-reserve" })
        XCTAssertEqual(reserve.name, "Chase Sapphire Reserve")
        XCTAssertEqual(reserve.rewardType, .points)
        let rules = Dictionary(uniqueKeysWithValues: reserve.rules.map { ($0.id, $0) })
        let lyft = try XCTUnwrap(rules["lyft"])
        XCTAssertEqual(lyft.earn, .points(pointsPerDollar: 5))
        XCTAssertEqual(lyft.merchants, ["Lyft"])
        XCTAssertEqual(lyft.expires, Day(2027, 9, 30))
        let peloton = try XCTUnwrap(rules["peloton"])
        XCTAssertEqual(peloton.earn, .points(pointsPerDollar: 10))
        XCTAssertEqual(peloton.expires, Day(2027, 12, 31))
        XCTAssertEqual(peloton.minimumSpend, 150)
        let chaseTravel = try XCTUnwrap(rules["chase-travel"])
        XCTAssertEqual(chaseTravel.earn, .points(pointsPerDollar: 8))
        XCTAssertEqual(chaseTravel.merchants, ["Chase Travel"])
        let dining = try XCTUnwrap(rules["dining"])
        XCTAssertEqual(dining.earn, .points(pointsPerDollar: 3))
        XCTAssertEqual(dining.categories, [.dining])
        let direct = try XCTUnwrap(rules["flights-hotels-direct"])
        XCTAssertEqual(direct.earn, .points(pointsPerDollar: 4))
        XCTAssertEqual(direct.categories, [.travel])
        let base = try XCTUnwrap(rules["base"])
        XCTAssertEqual(base.earn, .points(pointsPerDollar: 1))
        XCTAssertTrue(base.categories.isEmpty)
        XCTAssertTrue(base.merchants.isEmpty)
        XCTAssertNil(base.expires)
    }

    func testTodayUsesTheProvidedCalendar() {
        let epoch = Date(timeIntervalSince1970: 0)
        let day = Day.today(timeZone: TimeZone(secondsFromGMT: 0)!, now: epoch)
        XCTAssertEqual(day, Day(1970, 1, 1))
    }

    func testPointValueClampsAndSnapsSliderTenths() {
        XCTAssertEqual(PointValuation(centsPerPoint: 0).centsPerPoint, 1)
        XCTAssertEqual(PointValuation(centsPerPoint: decimal("1.25")).centsPerPoint, decimal("1.25"))
        XCTAssertEqual(PointValuation(centsPerPoint: 9).centsPerPoint, 2)
        XCTAssertEqual(PointValuation.standard.centsPerPoint, Decimal(15) / Decimal(10))
        XCTAssertEqual(PointValuation(sliderValue: 1.5).centsPerPoint, Decimal(15) / Decimal(10))
        XCTAssertEqual(PointValuation(sliderValue: 0.2).centsPerPoint, 1)
        XCTAssertEqual(PointValuation(sliderValue: 2.4).centsPerPoint, 2)
        XCTAssertEqual(PointValuation.standard.displayText, "1.5¢")
    }

    func testRejectedDateAndNegativeRate() {
        XCTAssertThrowsError(try CardCatalog.decode(Data("{\"cards\":[{\"id\":\"a\",\"name\":\"A\",\"issuer\":\"A\",\"rewardType\":\"cashback\",\"rules\":[{\"id\":\"r\",\"label\":\"L\",\"earn\":{\"kind\":\"cashback\",\"centsPerDollar\":3},\"expires\":\"2027-9-1\"}]}]}".utf8)))
        XCTAssertThrowsError(try CardCatalog.decode(Data("{\"cards\":[{\"id\":\"a\",\"name\":\"A\",\"issuer\":\"A\",\"rewardType\":\"points\",\"rules\":[{\"id\":\"r\",\"label\":\"L\",\"earn\":{\"kind\":\"points\",\"pointsPerDollar\":-1}}]}]}".utf8)))
    }
}
