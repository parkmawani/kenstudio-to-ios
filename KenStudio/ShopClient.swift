import Foundation
import SwiftSoup

/// 켄스튜디오(고도몰) PC 페이지 HTML을 받아 상품 데이터로 바꿉니다.
/// 공식 API가 아니라 HTML을 읽는 방식이라, 사이트 스킨이 바뀌면 이 파일의 선택자를 고쳐야 합니다.
struct ShopClient {
    static let shared = ShopClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            // PC 페이지 구조를 기준으로 파싱하므로 데스크톱 브라우저로 요청
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            "Accept-Language": "ko-KR,ko;q=0.9",
        ]
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    struct HomeData {
        let banners: [Banner]
        let sections: [HomeSection]
    }

    enum ShopError: LocalizedError {
        case badStatus(Int)
        var errorDescription: String? {
            switch self {
            case .badStatus(let code): return "서버 응답 오류 (\(code))"
            }
        }
    }

    // MARK: 요청

    func home() async throws -> HomeData {
        let doc = try await document(path: "/main/index.php", query: [])

        var banners: [Banner] = []
        var seen = Set<String>()
        for img in (try? doc.select(".slider-wrap img").array()) ?? [] {
            guard let src = try? img.absUrl("src"), !src.isEmpty,
                  let url = URL(string: src), !seen.contains(src) else { continue }
            seen.insert(src)
            var goodsNo: String?
            if let link = img.parent(), link.tagName() == "a", let href = try? link.attr("href") {
                goodsNo = Self.goodsNo(in: href)
            }
            banners.append(Banner(imageURL: url, goodsNo: goodsNo))
        }

        var sections: [HomeSection] = []
        for block in (try? doc.select(".main_goods_cont").array()) ?? [] {
            let title = Self.text(block, ".goods_list_tit h3") ?? "NEW ARRIVAL"
            let products = Self.parseProducts(in: block)
            if !products.isEmpty { sections.append(HomeSection(title: title, products: products)) }
        }
        return HomeData(banners: banners, sections: sections)
    }

    func list(cateCd: String, page: Int) async throws -> ProductPage {
        let doc = try await document(path: "/goods/goods_list.php", query: [
            URLQueryItem(name: "cateCd", value: cateCd),
            URLQueryItem(name: "page", value: String(page)),
        ])
        return ProductPage(products: Self.parseProducts(in: doc), hasNext: Self.hasPage(after: page, in: doc))
    }

    func search(keyword: String, page: Int) async throws -> ProductPage {
        let doc = try await document(path: "/goods/goods_search.php", query: [
            URLQueryItem(name: "keyword", value: keyword),
            URLQueryItem(name: "page", value: String(page)),
        ])
        return ProductPage(products: Self.parseProducts(in: doc), hasNext: Self.hasPage(after: page, in: doc))
    }

    private func document(path: String, query: [URLQueryItem]) async throws -> Document {
        var comps = URLComponents(string: Shop.host + path)!
        if !query.isEmpty { comps.queryItems = query }
        let url = comps.url!
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ShopError.badStatus(http.statusCode)
        }
        let html = String(decoding: data, as: UTF8.self)
        return try SwiftSoup.parse(html, url.absoluteString)
    }

    // MARK: 파싱

    static func parseProducts(in root: Element) -> [Product] {
        var result: [Product] = []
        var seen = Set<String>()
        for item in (try? root.select(".item_cont").array()) ?? [] {
            guard let link = try? item.select("a[href*=goodsNo]").first(),
                  let href = try? link.attr("href"),
                  let no = goodsNo(in: href), !seen.contains(no) else { continue }
            seen.insert(no)

            let name = text(item, ".item_name") ?? attr(item, ".item_photo_box img", "alt") ?? ""

            var image = attr(item, ".item_photo_box", "data-image-main")
            if image == nil, let img = try? item.select(".item_photo_box img").first() {
                image = try? img.absUrl("src")
            }

            let prices = wonValues(in: text(item, ".item_price") ?? "")
            let price = prices.first
            let sale = prices.count >= 2 ? prices.last : nil

            result.append(Product(
                id: no,
                name: name,
                imageURL: image.flatMap(URL.init(string:)),
                price: price,
                salePrice: (sale != nil && sale != price) ? sale : nil
            ))
        }
        return result
    }

    static func hasPage(after page: Int, in doc: Document) -> Bool {
        for a in (try? doc.select(".pagination a").array()) ?? [] {
            guard let href = try? a.attr("href") else { continue }
            if let n = firstMatch(#"[?&]page=(\d+)"#, in: href).flatMap(Int.init), n > page {
                return true
            }
        }
        return false
    }

    static func goodsNo(in href: String) -> String? {
        firstMatch(#"goodsNo=(\d+)"#, in: href)
    }

    static func wonValues(in text: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: #"([0-9][0-9,]*)\s*원"#) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { m in
            guard let r = Range(m.range(at: 1), in: text) else { return nil }
            return Int(text[r].replacingOccurrences(of: ",", with: ""))
        }
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func text(_ el: Element, _ css: String) -> String? {
        guard let found = try? el.select(css).first(), let t = try? found.text() else { return nil }
        let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func attr(_ el: Element, _ css: String, _ name: String) -> String? {
        guard let found = try? el.select(css).first(), let v = try? found.attr(name) else { return nil }
        let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
