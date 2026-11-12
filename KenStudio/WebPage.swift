import SwiftUI
import WebKit

// 상품 상세·장바구니·로그인·마이페이지 등 웹으로 남겨둔 화면

struct WebPage: UIViewRepresentable {
    let startURL: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()              // 로그인 쿠키 유지
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        // 일부 쇼핑몰은 "Safari"가 없는 기본 웹뷰 UA를 모바일 브라우저로 인식하지 못함
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true   // 스와이프로 뒤로/앞으로

        // 당겨서 새로고침
        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.pullToRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        context.coordinator.webView = webView
        webView.load(URLRequest(url: startURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?

        @objc func pullToRefresh(_ sender: UIRefreshControl) {
            webView?.reload()
        }

        // MARK: 링크 처리

        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url, let scheme = url.scheme?.lowercased() else {
                decisionHandler(.allow); return
            }
            let webSchemes: Set<String> = ["http", "https", "about", "data", "blob", "javascript"]
            if webSchemes.contains(scheme) {
                decisionHandler(.allow)
            } else {
                // 결제 앱(ISP, 카드사 앱), 카카오톡, tel:, mailto: 등은 외부 앱으로 넘김
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            }
        }

        // target="_blank" / window.open → 같은 화면에서 열기
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if action.targetFrame == nil {
                webView.load(action.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
            showError(error, in: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
            showError(error, in: webView)
        }

        // 웹 콘텐츠 프로세스가 죽으면 하얀 화면이 남으므로 다시 불러옴
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }

        // 로딩 실패를 하얀 화면 대신 화면에 표시 (원인 파악용)
        private func showError(_ error: Error, in webView: WKWebView) {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            if ns.domain == "WebKitErrorDomain" && ns.code == 102 { return } // 외부 앱으로 넘긴 링크
            let failedURL = (ns.userInfo[NSURLErrorFailingURLStringErrorKey] as? String) ?? "(알 수 없음)"
            let html = """
            <html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
            <body style="font-family:-apple-system;padding:24px;color:#222">
            <h3>페이지를 불러오지 못했어요</h3>
            <p>\(escape(ns.localizedDescription))</p>
            <p style="font-size:13px;color:#666">코드: \(escape(ns.domain)) \(ns.code)<br>주소: \(escape(failedURL))</p>
            <p><a href="\(escape(failedURL))">다시 시도</a></p>
            </body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }

        private func escape(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
        }

        // MARK: JS alert / confirm / prompt
        // 쇼핑몰은 "장바구니에 담았습니다" 같은 alert를 많이 써서, 이걸 구현 안 하면 버튼이 먹통처럼 보입니다.

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
            present(alert, fallback: completionHandler)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
            present(alert, fallback: { completionHandler(false) })
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            present(alert, fallback: { completionHandler(nil) })
        }

        private func present(_ alert: UIAlertController, fallback: @escaping () -> Void) {
            guard let vc = topViewController() else { fallback(); return }
            vc.present(alert, animated: true)
        }

        private func topViewController() -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            var vc = scene?.keyWindow?.rootViewController
            while let presented = vc?.presentedViewController { vc = presented }
            return vc
        }
    }
}
