import Foundation
import SwiftUI

/// 좋아요 목록 (기기에만 저장)
@MainActor
final class LikesStore: ObservableObject {
    @Published private(set) var items: [Product] = []
    private let key = "likes.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([Product].self, from: data) {
            items = saved
        }
    }

    func isLiked(_ product: Product) -> Bool {
        items.contains { $0.id == product.id }
    }

    func toggle(_ product: Product) {
        if let i = items.firstIndex(where: { $0.id == product.id }) {
            items.remove(at: i)
        } else {
            items.insert(product, at: 0)
        }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// 최근 검색어
@MainActor
final class RecentSearches: ObservableObject {
    @Published private(set) var items: [String] = []
    private let key = "recentSearches.v1"

    init() {
        items = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ keyword: String) {
        let k = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        items.removeAll { $0 == k }
        items.insert(k, at: 0)
        items = Array(items.prefix(15))
        UserDefaults.standard.set(items, forKey: key)
    }

    func remove(_ keyword: String) {
        items.removeAll { $0 == keyword }
        UserDefaults.standard.set(items, forKey: key)
    }

    func clear() {
        items = []
        UserDefaults.standard.set(items, forKey: key)
    }
}

@MainActor
final class HomeModel: ObservableObject {
    @Published var banners: [Banner] = []
    @Published var sections: [HomeSection] = []
    @Published var errorMessage: String?
    @Published var isLoaded = false

    func load() async {
        do {
            async let home = ShopClient.shared.home()
            async let best = ShopClient.shared.list(cateCd: "001004", page: 1)
            let data = try await home
            var sections = data.sections
            if let bestPage = try? await best, !bestPage.products.isEmpty {
                sections.append(HomeSection(title: "BEST ITEM", products: Array(bestPage.products.prefix(12))))
            }
            banners = data.banners
            self.sections = sections
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoaded = true
    }
}

/// 카테고리 목록 / 검색 결과를 페이지 단위로 불러옴
@MainActor
final class PagedProductsModel: ObservableObject {
    enum Source: Hashable {
        case category(String)
        case search(String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var reachedEnd = false

    let source: Source
    private var page = 0

    init(source: Source) {
        self.source = source
    }

    func reload() async {
        page = 0
        reachedEnd = false
        errorMessage = nil
        products = []
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, !reachedEnd else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next = page + 1
            let result: ProductPage
            switch source {
            case .category(let cateCd): result = try await ShopClient.shared.list(cateCd: cateCd, page: next)
            case .search(let keyword): result = try await ShopClient.shared.search(keyword: keyword, page: next)
            }
            page = next
            let existing = Set(products.map(\.id))
            let fresh = result.products.filter { !existing.contains($0.id) }
            products.append(contentsOf: fresh)
            reachedEnd = !result.hasNext || fresh.isEmpty
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
