import XCTest
import CardPickCore

final class BestCardPickerTests: XCTestCase {
    private var catalog: CardCatalog!

    override func setUpWithError() throws {
        catalog = try CardCatalog.bundled()
    }

    func testDiningTieAtOneCentPrefersCashBack() throws {
        let result = try recommend(.dining, centsPerPoint: "1.0")
        let runnerUp = try XCTUnwrap(result.runnerUp)
        XCTAssertEqual(result.winner.card.id, "robinhood-gold")
        XCTAssertEqual(result.winner.centsPerDollar, 3)
        XCTAssertEqual(runnerUp.card.id, "chase-sapphire-reserve")
        XCTAssertEqual(runnerUp.rule.id, "dining")
        XCTAssertEqual(runnerUp.centsPerDollar, 3)
        XCTAssertEqual(result.spokenAnswer, "Use Robinhood Gold — 3% back at Dining")
        XCTAssertEqual(result.comparisonNote, "Tied on earn rate. Cash back wins the tie.")
    }

    func testDiningAtOneAndAHalfPrefersSapphire() throws {
        let result = try recommend(.dining, centsPerPoint: "1.5")
        let runnerUp = try XCTUnwrap(result.runnerUp)
        XCTAssertEqual(result.winner.card.id, "chase-sapphire-reserve")
        XCTAssertEqual(result.winner.rule.id, "dining")
        XCTAssertEqual(result.winner.shortRate, "3x points")
        XCTAssertEqual(result.winner.centsPerDollar, decimal("4.5"))
        XCTAssertEqual(runnerUp.card.id, "robinhood-gold")
        XCTAssertEqual(runnerUp.centsPerDollar, 3)
        XCTAssertEqual(result.spokenAnswer, "Use Chase Sapphire Reserve — 3x points at Dining")
        XCTAssertEqual(result.comparisonNote, "1.5¢ per $1 more than Robinhood Gold")
    }

    func testLyftPrefersSapphire() throws {
        let result = try recommend(.other, merchant: "Lyft")
        XCTAssertEqual(result.winner.card.id, "chase-sapphire-reserve")
        XCTAssertEqual(result.winner.rule.id, "lyft")
        XCTAssertEqual(result.winner.centsPerDollar, decimal("7.5"))
        XCTAssertEqual(result.winner.matchedMerchantName, "Lyft")
        XCTAssertEqual(result.spokenAnswer, "Use Chase Sapphire Reserve — 5x points at Lyft")
    }

    func testLyftPhraseMatchesInsideThePlaceName() throws {
        let result = try recommend(.dining, merchant: "Lyft Hub")
        XCTAssertEqual(result.winner.rule.id, "lyft")
        XCTAssertEqual(result.placePhrase, "Lyft")
    }

    func testGasPrefersRobinhood() throws {
        let result = try recommend(.gas)
        let runnerUp = try XCTUnwrap(result.runnerUp)
        XCTAssertEqual(result.winner.card.id, "robinhood-gold")
        XCTAssertEqual(result.winner.shortRate, "3% back")
        XCTAssertEqual(result.winner.centsPerDollar, 3)
        XCTAssertEqual(runnerUp.card.id, "chase-sapphire-reserve")
        XCTAssertEqual(runnerUp.rule.id, "base")
        XCTAssertEqual(runnerUp.centsPerDollar, decimal("1.5"))
        XCTAssertEqual(result.spokenAnswer, "Use Robinhood Gold — 3% back at Gas")
    }

    func testExpiredLyftPromoIsIgnored() throws {
        let expired = try recommend(.other, merchant: "Lyft", on: Day(2027, 10, 1))
        let runnerUp = try XCTUnwrap(expired.runnerUp)
        XCTAssertEqual(expired.winner.card.id, "robinhood-gold")
        XCTAssertEqual(runnerUp.rule.id, "base")
        XCTAssertNotEqual(expired.winner.rule.id, "lyft")
        XCTAssertNotEqual(runnerUp.rule.id, "lyft")

        let lastDay = try recommend(.other, merchant: "Lyft", on: Day(2027, 9, 30))
        XCTAssertEqual(lastDay.winner.rule.id, "lyft")
    }

    func testExpiredLyftFallsThroughToDiningRatherThanThePromo() throws {
        let result = try recommend(.dining, merchant: "Lyft", on: Day(2027, 10, 1))
        XCTAssertEqual(result.winner.card.id, "chase-sapphire-reserve")
        XCTAssertEqual(result.winner.rule.id, "dining")
        XCTAssertEqual(result.winner.centsPerDollar, decimal("4.5"))
    }

    func testManualCategoryOverrideSkipsMerchantOffers() throws {
        let result = try recommend(.dining, merchant: "Lyft", matchMerchants: false)
        XCTAssertEqual(result.winner.rule.id, "dining")
        XCTAssertNil(result.winner.matchedMerchantName)
        XCTAssertEqual(result.spokenAnswer, "Use Chase Sapphire Reserve — 3x points at Dining")
    }

    func testCategoryWinnersAtDefaultPointValue() throws {
        let expected: [(RewardCategory, String, String)] = [
            (.dining, "chase-sapphire-reserve", "dining"),
            (.gas, "robinhood-gold", "everything"),
            (.groceries, "robinhood-gold", "everything"),
            (.travel, "chase-sapphire-reserve", "flights-hotels-direct"),
            (.drugstore, "robinhood-gold", "everything"),
            (.other, "robinhood-gold", "everything")
        ]
        for (category, cardID, ruleID) in expected {
            let result = try recommend(category)
            XCTAssertEqual(result.winner.card.id, cardID, category.rawValue)
            XCTAssertEqual(result.winner.rule.id, ruleID, category.rawValue)
        }
    }

    func testGasStillPrefersRobinhoodWhenPointsAreWorthTwoCents() throws {
        let result = try recommend(.gas, centsPerPoint: "2.0")
        XCTAssertEqual(result.winner.card.id, "robinhood-gold")
        XCTAssertEqual(try XCTUnwrap(result.runnerUp).centsPerDollar, 2)
    }

    func testChaseTravelBeatsDirectHotelRate() throws {
        let direct = try recommend(.travel, merchant: "The Hoxton")
        XCTAssertEqual(direct.winner.rule.id, "flights-hotels-direct")
        XCTAssertEqual(direct.winner.centsPerDollar, 6)

        let portal = try recommend(.travel, merchant: "Chase Travel")
        XCTAssertEqual(portal.winner.rule.id, "chase-travel")
        XCTAssertEqual(portal.winner.centsPerDollar, 12)
        XCTAssertEqual(portal.spokenAnswer, "Use Chase Sapphire Reserve — 8x points at Chase Travel")
    }

    func testPelotonRequiresKnownSpendAndIgnoresThePromoAfterExpiry() throws {
        let unknownSpend = try recommend(.other, merchant: "Peloton")
        XCTAssertEqual(unknownSpend.winner.card.id, "robinhood-gold")

        let tooSmall = try recommend(.other, merchant: "Peloton", spend: "149.99")
        XCTAssertEqual(tooSmall.winner.card.id, "robinhood-gold")

        let qualifies = try recommend(.other, merchant: "Peloton", spend: "150")
        XCTAssertEqual(qualifies.winner.rule.id, "peloton")
        XCTAssertEqual(qualifies.winner.centsPerDollar, 15)
        XCTAssertEqual(qualifies.spokenAnswer, "Use Chase Sapphire Reserve — 10x points at Peloton")

        let expired = try recommend(.other, merchant: "Peloton", spend: "200", on: Day(2028, 1, 1))
        XCTAssertEqual(expired.winner.card.id, "robinhood-gold")
    }

    func testPelotonPromoIsLiveOnItsLastDay() throws {
        let result = try recommend(.other, merchant: "Peloton", spend: "150", on: Day(2027, 12, 31))
        XCTAssertEqual(result.winner.rule.id, "peloton")
    }

    func testEmptyCatalogReturnsNil() {
        let picker = BestCardPicker(catalog: CardCatalog(cards: []))
        let context = PurchaseContext(category: .dining, on: Day(2026, 10, 31))
        XCTAssertNil(picker.recommend(context: context, valuation: .standard))
    }

    private func recommend(
        _ category: RewardCategory,
        merchant: String? = nil,
        spend: String? = nil,
        on: Day = Day(2026, 10, 31),
        centsPerPoint: String = "1.5",
        matchMerchants: Bool = true
    ) throws -> Recommendation {
        let context = PurchaseContext(
            category: category,
            merchant: merchant,
            spend: spend.map(decimal),
            on: on,
            matchMerchants: matchMerchants
        )
        let cents = decimal(centsPerPoint)
        let result = BestCardPicker(catalog: catalog).recommend(
            context: context,
            valuation: PointValuation(centsPerPoint: cents)
        )
        return try XCTUnwrap(result)
    }
}
