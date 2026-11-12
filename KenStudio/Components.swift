import SwiftUI

enum Theme {
    static let background = Color.black
    static let placeholder = Color(white: 0.11)
    static let secondary = Color(white: 0.58)
    static let sale = Color(red: 1.0, green: 0.33, blue: 0.33)
    static let imageAspect: CGFloat = 500.0 / 643.0   // 사이트 상품 이미지 비율
}

/// 브랜드 로고 텍스트
struct BrandTitle: View {
    var body: some View {
        Text("KEN STUDIO")
            .font(.system(size: 17, weight: .black))
            .tracking(4)
    }
}

/// 화면 너비에 따라 열 수가 늘어나는 상품 그리드 (아이폰 3열, 펼친 화면은 더 많이)
struct ProductGrid: View {
    let products: [Product]
    var onReachEnd: (() -> Void)? = nil

    private let columns = [GridItem(.adaptive(minimum: 108, maximum: 220), spacing: 8, alignment: .top)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
            ForEach(products) { product in
                NavigationLink(value: Route.product(product)) {
                    ProductCard(product: product)
                }
                .buttonStyle(.plain)
                .onAppear {
                    if product.id == products.last?.id { onReachEnd?() }
                }
            }
        }
        .padding(.horizontal, 10)
    }
}

struct ProductCard: View {
    let product: Product
    @EnvironmentObject private var likes: LikesStore

    var body: some View {
        let liked = likes.isLiked(product)
        VStack(alignment: .leading, spacing: 6) {
            Theme.placeholder
                .aspectRatio(Theme.imageAspect, contentMode: .fit)
                .overlay {
                    AsyncImage(url: product.imageURL, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Theme.placeholder
                        }
                    }
                }
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        likes.toggle(product)
                    } label: {
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(liked ? Theme.sale : .white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(liked ? "좋아요 취소" : "좋아요")
                }

            Text(product.name)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            PriceLabel(product: product)
        }
    }
}

struct PriceLabel: View {
    let product: Product

    var body: some View {
        HStack(spacing: 4) {
            if let discount = product.discountPercent {
                Text("\(discount)%")
                    .foregroundStyle(Theme.sale)
            }
            Text(Won.string(product.finalPrice))
                .foregroundStyle(.white)
        }
        .font(.system(size: 13, weight: .bold))
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
    }
}

struct ErrorRetryView: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(Theme.secondary)
            Text("불러오지 못했어요")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") { Task { await retry() } }
                .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// 무한 스크롤 상품 목록 (카테고리, 검색 결과 공용)
struct PagedProductsView: View {
    @ObservedObject var model: PagedProductsModel
    var emptyText = "상품이 없어요"

    var body: some View {
        ScrollView {
            ProductGrid(products: model.products) {
                Task { await model.loadMore() }
            }
            .padding(.top, 8)

            Group {
                if model.isLoading {
                    ProgressView().padding(24)
                } else if let error = model.errorMessage {
                    ErrorRetryView(message: error) { await model.loadMore() }
                } else if model.reachedEnd && model.products.isEmpty {
                    Text(emptyText)
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 60)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .refreshable { await model.reload() }
        .task {
            if model.products.isEmpty && !model.reachedEnd { await model.loadMore() }
        }
    }
}
