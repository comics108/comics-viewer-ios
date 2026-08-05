#if canImport(UIKit)
import UIKit
import XCTest
@testable import ComicsViewer

@MainActor
final class ImageScrollViewTests: XCTestCase {
    func testPreviewFilteringLanguageNormalizationAndDispose() throws {
        let data = Data("""
        {
          "width": 100,
          "height": 200,
          "layers": [
            {"preview": false, "images": [{"width": 10, "height": 10, "file": "a_{0}_{1}_{2}.png"}], "animations": []},
            {"preview": true, "images": [{"width": 10, "height": 10, "file": "b_{0}_{1}_{2}.png"}], "animations": []}
          ],
          "sounds": []
        }
        """.utf8)
        let comics = try JSONDecoder().decode(Comics.self, from: data)
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let view = ImageScrollView()

        view.install(comics: comics, resources: ArchiveManager(rootURL: root))
        XCTAssertEqual(view.layerTiles.count, 2)

        view.showPreview = false
        XCTAssertEqual(view.layerTiles.count, 1)
        XCTAssertFalse(view.layerTiles[0].layer.isPreview)

        view.languageIndex = -5
        XCTAssertEqual(view.languageIndex, 0)

        view.dispose()
        XCTAssertNil(view.comics)
        XCTAssertTrue(view.layerTiles.isEmpty)
    }
}
#endif
