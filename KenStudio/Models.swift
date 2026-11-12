import Foundation

struct Product: Identifiable, Hashable, Codable {
    let id: String          // 고도몰 goodsNo
    let name: String
    let imageURL: URL?
    let price: Int?         // 정가
    let salePrice: Int?     // 타임세일 등 할인가

    var finalPrice: Int? { salePrice ?? price }

    var discountPercent: Int? {
        guard let p = price, let s = salePrice, p > s, p > 0 else { return nil }
        return Int((Double(p - s) / Double(p) * 100).rounded())
    }

    var pageURL: URL { Shop.goodsURL(id) }
}

struct Banner: Identifiable, Hashable {
    var id: String { imageURL.absoluteString }
    let imageURL: URL
    let goodsNo: String?
}

struct HomeSection: Identifiable {
    var id: String { title }
    let title: String
    let products: [Product]
}

struct ProductPage {
    let products: [Product]
    let hasNext: Bool
}

struct ShopCategory: Identifiable, Hashable {
    let id: String      // cateCd
    let name: String
}

struct CategoryGroup: Identifiable {
    var id: String { title }
    let title: String
    let items: [ShopCategory]
}

enum Route: Hashable {
    case product(Product)
    case category(ShopCategory)
    case web(URL, String)
}

enum Shop {
    static let host = "https://www.kenstudio.co.kr"

    static func goodsURL(_ goodsNo: String) -> URL {
        URL(string: "\(host)/goods/goods_view.php?goodsNo=\(goodsNo)")!
    }

    static let cartURL = URL(string: "\(host)/order/cart.php")!
    static let myPageURL = URL(string: "\(host)/mypage/index.php")!
    static let homeURL = URL(string: "\(host)/")!

    // 사이트 사이드 메뉴 기준 카테고리
    static let groups: [CategoryGroup] = [
        CategoryGroup(title: "UNISEX", items: [
            ShopCategory(id: "001003", name: "전체"),
            ShopCategory(id: "001004", name: "베스트"),
            ShopCategory(id: "001001", name: "아우터"),
            ShopCategory(id: "001002", name: "상의 · 셔츠"),
            ShopCategory(id: "001005", name: "하의 · 스커트"),
            ShopCategory(id: "001006", name: "가방 · 액세서리"),
        ]),
        CategoryGroup(title: "WOMEN", items: [
            ShopCategory(id: "012001", name: "전체"),
            ShopCategory(id: "012002", name: "베스트"),
            ShopCategory(id: "012003", name: "아우터"),
            ShopCategory(id: "012004", name: "상의 · 셔츠"),
            ShopCategory(id: "012005", name: "하의 · 스커트"),
            ShopCategory(id: "012007", name: "가방 · 액세서리"),
        ]),
    ]
}

enum Won {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    static func string(_ value: Int?) -> String {
        guard let value else { return "" }
        return (formatter.string(from: NSNumber(value: value)) ?? "\(value)") + "원"
    }
}
