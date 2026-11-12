import SwiftUI

@main
struct KenStudioApp: App {
    @StateObject private var likes = LikesStore()
    @StateObject private var recents = RecentSearches()

    init() {
        // 상품 이미지 캐시를 넉넉하게
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 512 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(likes)
                .environmentObject(recents)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("홈", systemImage: "house") }
            CategoryView()
                .tabItem { Label("카테고리", systemImage: "square.grid.2x2") }
            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }
            LikesView()
                .tabItem { Label("좋아요", systemImage: "heart") }
            MyPageView()
                .tabItem { Label("마이", systemImage: "person") }
        }
    }
}

// MARK: 공통 내비게이션

extension View {
    /// 각 탭의 첫 화면에 붙이는 공통 목적지 + 장바구니 버튼
    func shopNavigation() -> some View {
        self
            .navigationDestination(for: Route.self) { route in
                RouteView(route: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.web(Shop.cartURL, "장바구니")) {
                        Image(systemName: "bag")
                    }
                }
            }
    }
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .product(let product):
            WebScreen(url: product.pageURL, title: "")
        case .category(let category):
            CategoryProductsView(category: category)
        case .web(let url, let title):
            WebScreen(url: url, title: title)
        }
    }
}

struct WebScreen: View {
    let url: URL
    let title: String

    var body: some View {
        WebPage(startURL: url)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: 마이 (웹)

struct MyPageView: View {
    var body: some View {
        NavigationStack {
            WebPage(startURL: Shop.myPageURL)
                .navigationTitle("마이페이지")
                .navigationBarTitleDisplayMode(.inline)
                .shopNavigation()
        }
    }
}
