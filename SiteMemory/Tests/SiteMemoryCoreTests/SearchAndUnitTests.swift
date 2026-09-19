import XCTest
@testable import SiteMemoryCore

final class MetadataSearchTests: XCTestCase {
    private let index = MetadataSearchIndex()

    private func photo(
        categories: [ObjectCategory],
        tags: [String] = [],
        note: String? = nil,
        daysAgo: Int = 0
    ) -> SitePhoto {
        SitePhoto(
            wallID: .init(),
            capturedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            imageReference: .appContainer(relativePath: "p.jpg"),
            imageSize: ImageSize(pixelWidth: 100, pixelHeight: 100),
            annotations: categories.map { HiddenObjectAnnotation(category: $0, region: .point(.init(x: 0.5, y: 0.5))) },
            visionTags: tags,
            note: note
        )
    }

    func testCategoryFilterMatchesOnlyRelevantPhotos() async throws {
        let photos = [
            photo(categories: [.waterPipe]),
            photo(categories: [.electricalCable]),
            photo(categories: [.waterPipe, .metalStud])
        ]
        let results = try await index.search(SiteQuery(categories: [.waterPipe]), in: photos)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.matchedCategories.contains(.waterPipe) })
    }

    func testEmptyQueryReturnsEverything() async throws {
        let photos = [photo(categories: [.gasPipe]), photo(categories: [.insulation])]
        let results = try await index.search(SiteQuery(), in: photos)
        XCTAssertEqual(results.count, 2)
    }

    func testTextMatchesVisionTags() async throws {
        let photos = [
            photo(categories: [.waterPipe], tags: ["copper", "pipe"]),
            photo(categories: [.waterPipe], tags: ["pex"])
        ]
        let results = try await index.search(
            SiteQuery(categories: [.waterPipe], text: "copper"), in: photos
        )
        XCTAssertEqual(results.first?.matchedCategories, [.waterPipe])
        XCTAssertGreaterThan(results.first?.score ?? 0, results.last?.score ?? 1)
    }

    func testDateRangeExcludesOldPhotos() async throws {
        let recent = photo(categories: [.embed], daysAgo: 1)
        let old = photo(categories: [.embed], daysAgo: 400)
        let range = Calendar.current.date(byAdding: .day, value: -30, to: Date())!...Date()
        let results = try await index.search(
            SiteQuery(categories: [.embed], dateRange: range), in: [recent, old]
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.photo.id, recent.id)
    }
}

final class LengthFormattingTests: XCTestCase {
    func testMetricFormatting() {
        XCTAssertEqual(Length.millimetres(320).formatted(.metric), "320 mm")
        XCTAssertEqual(Length.metres(1.18).formatted(.metric), "1.18 m")
    }

    func testImperialFormatting() {
        XCTAssertEqual(Length.inches(6).formatted(.imperial), "6.0\"")
        XCTAssertEqual(Length.feet(3).formatted(.imperial), "3' 0\"")
    }

    func testUnitDefaultsByCountry() {
        XCTAssertEqual(UnitSystem.default(forCountryCode: "US"), .imperial)
        XCTAssertEqual(UnitSystem.default(forCountryCode: "DE"), .metric)
        XCTAssertEqual(UnitSystem.default(forCountryCode: nil), .metric)
    }

    func testReportBuilderSummarizesPosition() {
        let builder = WallMemoryReportBuilder(unitSystem: .metric)
        let annotation = HiddenObjectAnnotation(
            category: .waterPipe,
            region: .point(.init(x: 0.5, y: 0.5)),
            position: PlanarPosition(
                distanceFromLeft: .millimetres(320),
                distanceFromTop: .metres(1.18),
                confidence: 0.8
            )
        )
        let photo = SitePhoto(
            wallID: .init(),
            imageReference: .appContainer(relativePath: "p.jpg"),
            imageSize: ImageSize(pixelWidth: 100, pixelHeight: 100),
            annotations: [annotation]
        )
        let wall = Wall(roomID: .init(), name: "North wall")
        let report = builder.makeReport(wall: wall, roomName: "Kitchen", photos: [photo])
        XCTAssertEqual(report.entries.first?.positionSummary, "320 mm from left · 1.18 m down")
    }
}
