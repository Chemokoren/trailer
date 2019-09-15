import WebKit
import CoreData

final class DetailViewController: UIViewController, WKNavigationDelegate {
	
	@IBOutlet private weak var spinner: UIActivityIndicatorView!
	@IBOutlet private weak var statusLabel: UILabel!
	@IBOutlet private weak var webView: WKWebView!

	private var alwaysRequestDesktopSite = false
	
	var isVisible = false
	var catchupWithDataItemWhenLoaded: NSManagedObjectID?
	
	var detailItem: URL? {
		didSet {
			configureView()
		}
	}
    
    private var titleObserver: NSObjectProtocol?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Loading…"
		webView.navigationDelegate = self
		configureView()
        titleObserver = NotificationCenter.default.addObserver(forName: .MasterViewTitleChanged, object: nil, queue: OperationQueue.main) { [weak self] notification in
            guard let newTitle = notification.object as? String else { return }
            self?.navigationItem.leftBarButtonItem?.title = newTitle
        }
	}
    
    deinit {
        if let t = titleObserver {
            NotificationCenter.default.removeObserver(t)
            titleObserver = nil
        }
    }
		
	@objc private func configureView() {
		guard let webView = webView else { return }
		if let d = detailItem {
			if !alwaysRequestDesktopSite && Settings.alwaysRequestDesktopSite {
				DLog("Activating iPad webview user-agent")
				alwaysRequestDesktopSite = true
				webView.evaluateJavaScript("navigator.userAgent") { result, error in
					if let r = result as? String {
						self.webView.customUserAgent = r.replacingOccurrences(of: "iPhone", with: "iPad")
					}
					self.configureView()
				}
				return
			} else if alwaysRequestDesktopSite && !Settings.alwaysRequestDesktopSite {
				DLog("Deactivating iPad webview user-agent")
				webView.customUserAgent = nil
				alwaysRequestDesktopSite = false
			}
			DLog("Will load: %@", d.absoluteString)
			webView.load(URLRequest(url: d))
		} else {
			statusLabel.textColor = tertiaryLabelColour
			statusLabel.text = "Please select an item from the list, or visit the settings to add servers, or show/hide repositories.\n\n(You may have to login to GitHub the first time you visit a private item)"
			statusLabel.isHidden = false
			navigationItem.rightBarButtonItem?.isEnabled = false
			title = nil
			webView.isHidden = true
		}
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		navigationItem.leftBarButtonItem = (traitCollection.horizontalSizeClass == .compact) ? nil : splitViewController?.displayModeButtonItem
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if let w = webView, w.isLoading {
			spinner.startAnimating()
		} else { // Same item re-selected
			spinner.stopAnimating()
			catchupWithComments()
		}
		isVisible = true
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		isVisible = false
		super.viewDidDisappear(animated)
	}
	
	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		spinner.startAnimating()
		statusLabel.isHidden = true
		statusLabel.text = nil
		webView.isHidden = true
		title = "Loading…"
		navigationItem.rightBarButtonItem = nil
	}
	
	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		if let res = navigationResponse.response as? HTTPURLResponse, res.statusCode == 404 {
			showMessage("Not Found", "\nPlease ensure you are logged in with the correct account on GitHub\n\nIf you are using two-factor auth: There is a bug between GitHub and iOS which may cause your login to fail.  If it happens, temporarily disable two-factor auth and log in from here, then re-enable it afterwards.  You will only need to do this once.")
		}
		decisionHandler(.allow)
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		spinner.stopAnimating()
		statusLabel.isHidden = true
		webView.isHidden = false
		navigationItem.rightBarButtonItem?.isEnabled = true
		title = webView.title
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareSelected))
		
		catchupWithComments()
		if splitViewController?.isCollapsed ?? true {
			becomeFirstResponder()
		}
	}
	
	override var keyCommands: [UIKeyCommand]? {
		let ff = UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: .command, action: #selector(focusOnMaster), discoverabilityTitle: "Focus keyboard on item list")
		let s = UIKeyCommand(input: "o", modifierFlags: .command, action: #selector(keyOpenInSafari), discoverabilityTitle: "Open in Safari")
		return [ff,s]
	}
	
	@objc private func keyOpenInSafari() {
		if let u = webView?.url {
			UIApplication.shared.open(u, options: [:], completionHandler: nil)
		}
	}
	
	@discardableResult
	override func becomeFirstResponder() -> Bool {
		if detailItem != nil {
			return webView?.becomeFirstResponder() ?? false
		} else {
			return false
		}
	}
	
	@objc private func focusOnMaster() {
		let m = popupManager.masterController
		if splitViewController?.isCollapsed ?? true {
			_ = m.navigationController?.popViewController(animated: true)
		}
		m.becomeFirstResponder()
	}
	
	private func catchupWithComments() {
		if let oid = catchupWithDataItemWhenLoaded, let dataItem = existingObject(with: oid) as? ListableItem {
			if dataItem.hasUnreadCommentsOrAlert {
				dataItem.catchUpWithComments()
			}
		}
		catchupWithDataItemWhenLoaded = nil
	}
	
	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		loadFailed(error: error)
	}
	
	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		loadFailed(error: error)
	}
	
	private func loadFailed(error: Error) {
		spinner.stopAnimating()
		statusLabel.textColor = .red
		statusLabel.text = "Loading Error: \(error.localizedDescription)"
		statusLabel.isHidden = false
		webView?.isHidden = true
		title = "Error"
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(configureView))
	}
	
	@objc private func shareSelected() {
		if let u = webView?.url {
			popupManager.shareFromView(view: self, buttonItem: navigationItem.rightBarButtonItem!, url: u)
		}
	}
}
