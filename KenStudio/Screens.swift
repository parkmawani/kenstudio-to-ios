import SwiftUI

// MARK: 홈

struct HomeView: View {
    @StateObject private var model = HomeModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if !model.banners.isEmpty {
                        BannerCarousel(banners: model.banners)
                    }
                    ForEach(model.sections) { section in
                        VStack(spacing: 12) {
                            SectionHeader(title: section.title)
                            ProductGrid(products: section.products)
                        }
                    }
                    if !model.isLoaded {
                        ProgressView().padding(.top, 120)
                    } else if let error = model.errorMessage, model.sections.isEmpty {
                        ErrorRetryView(message: error) { await model.load() }
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .refreshable { await model.load() }
            .task { if !model.isLoaded { await model.load() } }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { BrandTitle() }
            }
            .shopNavigation()
        }
    }
}

struct BannerCarousel: View {
    let banners: [Banner]
    @State private var index = 0

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(banners.enumerated()), id: \.element.id) { offset, banner in
                bannerLink(banner).tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .aspectRatio(1, contentMode: .fit)
        .frame(maxHeight: 560)
        .task(id: banners.count) {
            // 4초마다 자동 넘김
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled, banners.count > 1 else { continue }
                withAnimation(.easeInOut) { index = (index + 1) % banners.count }
            }
        }
    }

    @ViewBuilder
    private func bannerLink(_ banner: Banner) -> some View {
        let image = AsyncImage(url: banner.imageURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Theme.placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()

        if let no = banner.goodsNo {
            NavigationLink(value: Route.web(Shop.goodsURL(no), "")) { image }
                .buttonStyle(.plain)
        } else {
            image
        }
    }
}

// MARK: 카테고리

struct CategoryView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(Shop.groups) { group in
                    Section {
                        ForEach(group.items) { category in
                            NavigationLink(value: Route.category(category)) {
                                Text(category.name)
                                    .font(.system(size: 15))
                            }
                        }
                    } header: {
                        Text(group.title)
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("카테고리")
            .shopNavigation()
        }
    }
}

struct CategoryProductsView: View {
    let category: ShopCategory
    @StateObject private var model: PagedProductsModel

    init(category: ShopCategory) {
        self.category = category
        _model = StateObject(wrappedValue: PagedProductsModel(source: .category(category.id)))
    }

    var body: some View {
        PagedProductsView(model: model)
            .navigationTitle(categoryTitle)
            .navigationBarTitleDisplayMode(.inline)
    }

    private var categoryTitle: String {
        let group = Shop.groups.first { $0.items.contains(category) }?.title
        return [group, category.name].compactMap { $0 }.joined(separator: " · ")
    }
}

// MARK: 검색

struct SearchView: View {
    @EnvironmentObject private var recents: RecentSearches
    @State private var query = ""
    @State private var submitted: String?

    var body: some View {
        NavigationStack {
            Group {
                if let keyword = submitted {
                    SearchResultsView(keyword: keyword)
                        .id(keyword)
                } else {
                    recentList
                }
            }
            .background(Theme.background)
            .navigationTitle("검색")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "상품명 검색")
            .onSubmit(of: .search) { run(query) }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty { submitted = nil }
            }
            .shopNavigation()
        }
    }

    private var recentList: some View {
        List {
            if recents.items.isEmpty {
                Text("최근 검색어가 없어요")
                    .foregroundStyle(Theme.secondary)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(recents.items, id: \.self) { keyword in
                        Button {
                            query = keyword
                            run(keyword)
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(Theme.secondary)
                                Text(keyword).foregroundStyle(.white)
                            }
                        }
                        .swipeActions {
                            Button("삭제", role: .destructive) { recents.remove(keyword) }
                        }
                    }
                } header: {
                    HStack {
                        Text("최근 검색어")
                        Spacer()
                        Button("전체 삭제") { recents.clear() }
                            .font(.caption)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func run(_ keyword: String) {
        let k = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        recents.add(k)
        submitted = k
    }
}

struct SearchResultsView: View {
    @StateObject private var model: PagedProductsModel

    init(keyword: String) {
        _model = StateObject(wrappedValue: PagedProductsModel(source: .search(keyword)))
    }

    var body: some View {
        PagedProductsView(model: model, emptyText: "검색 결과가 없어요")
    }
}

// MARK: 좋아요

struct LikesView: View {
    @EnvironmentObject private var likes: LikesStore

    var body: some View {
        NavigationStack {
            Group {
                if likes.items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "heart")
                            .font(.system(size: 32))
                            .foregroundStyle(Theme.secondary)
                        Text("좋아요한 상품이 없어요")
                            .foregroundStyle(Theme.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        ProductGrid(products: likes.items)
                            .padding(.vertical, 8)
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("좋아요")
            .navigationBarTitleDisplayMode(.inline)
            .shopNavigation()
        }
    }
}
