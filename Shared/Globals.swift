
////////////////////// Global variables

#if os(iOS)

import UIKit
import CoreData

weak var app: iOS_AppDelegate!

let GLOBAL_SCREEN_SCALE = UIScreen.main.scale
let DISABLED_FADE: CGFloat = 0.3

var labelColour: UIColor = {
    if #available(iOS 13, *) {
        return UIColor.label
    } else {
        return UIColor.darkText
    }
}()

var secondaryLabelColour: UIColor = {
    if #available(iOS 13, *) {
        return UIColor.secondaryLabel
    } else {
        return UIColor.darkGray
    }
}()

var tertiaryLabelColour: UIColor = {
    if #available(iOS 13, *) {
        return UIColor.tertiaryLabel
    } else {
        return UIColor.lightGray
    }
}()

typealias COLOR_CLASS = UIColor
typealias FONT_CLASS = UIFont
typealias IMAGE_CLASS = UIImage

let stringDrawingOptions: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

#elseif os(OSX)

weak var app: OSX_AppDelegate!

let AVATAR_SIZE: CGFloat = 26
let AVATAR_PADDING: CGFloat = 8
let LEFTPADDING: CGFloat = 44
let MENU_WIDTH: CGFloat = 500
let REMOVE_BUTTON_WIDTH: CGFloat = 80
let DISABLED_FADE: CGFloat = 0.4

typealias COLOR_CLASS = NSColor
typealias FONT_CLASS = NSFont
typealias IMAGE_CLASS = NSImage

let stringDrawingOptions: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

#endif

var appIsRefreshing = false
var preferencesDirty = false
var lastRepoCheck = Date.distantPast
let autoSnoozeSentinelDate = Date.distantFuture.addingTimeInterval(-1)
let LISTABLE_URI_KEY = "listableUriKey"
let COMMENT_ID_KEY = "commentIdKey"
let NOTIFICATION_URL_KEY = "urlKey"

////////////////////////// Utilities

#if os(iOS)

	func showMessage(_ title: String, _ message: String?) {
		var viewController = app.window?.rootViewController
		while viewController?.presentedViewController != nil {
			viewController = viewController?.presentedViewController
		}

		let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
		a.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
		viewController?.present(a, animated: true)
	}

#endif

func existingObject(with id: NSManagedObjectID) -> NSManagedObject? {
	return try? DataManager.main.existingObject(with: id)
}

let itemDateFormatter: DateFormatter = {
	let f = DateFormatter()
	f.dateStyle = .medium
	f.timeStyle = .short
	f.doesRelativeDateFormatting = true
	return f
}()

func DLog(_ message: String, _ arg1: @autoclosure ()->Any? = nil, _ arg2: @autoclosure ()->Any? = nil, _ arg3: @autoclosure ()->Any? = nil, _ arg4: @autoclosure ()->Any? = nil, _ arg5: @autoclosure ()->Any? = nil) {
	if Settings.logActivityToConsole {
		NSLog(message,
		      String(describing: arg1() ?? "(nil)"),
		      String(describing: arg2() ?? "(nil)"),
		      String(describing: arg3() ?? "(nil)"),
		      String(describing: arg4() ?? "(nil)"),
		      String(describing: arg5() ?? "(nil)"))
	}
}

let itemCountFormatter: NumberFormatter = {
	let n = NumberFormatter()
	n.numberStyle = .decimal
	return n
}()

func bootUp() {
	Settings.checkMigration()
	DataManager.checkMigration()
	API.setup()
}

//////////////////////// Enums

enum ItemCondition: Int64 {
	case open, closed, merged

	static private var predicateMatchCache = [ItemCondition : NSPredicate]()
	var matchingPredicate: NSPredicate {
		if let predicate = ItemCondition.predicateMatchCache[self] {
			return predicate
		}
		let predicate = NSPredicate(format: "condition == %lld", rawValue)
		ItemCondition.predicateMatchCache[self] = predicate
		return predicate
	}
	static private var predicateExcludeCache = [ItemCondition : NSPredicate]()
	var excludingPredicate: NSPredicate {
		if let predicate = ItemCondition.predicateExcludeCache[self] {
			return predicate
		}
		let predicate = NSPredicate(format: "condition != %lld", rawValue)
		ItemCondition.predicateExcludeCache[self] = predicate
		return predicate
	}
}

enum StatusFilter: Int {
	case all, include, exclude
}

enum PostSyncAction: Int64 {
	case doNothing, delete, isNew, isUpdated

	static private var predicateMatchCache = [PostSyncAction : NSPredicate]()
	var matchingPredicate: NSPredicate {
		if let predicate = PostSyncAction.predicateMatchCache[self] {
			return predicate
		}
		let predicate = NSPredicate(format: "postSyncAction == %lld", rawValue)
		PostSyncAction.predicateMatchCache[self] = predicate
		return predicate
	}
	static private var predicateExcludeCache = [PostSyncAction : NSPredicate]()
	var excludingPredicate: NSPredicate {
		if let predicate = PostSyncAction.predicateExcludeCache[self] {
			return predicate
		}
		let predicate = NSPredicate(format: "postSyncAction != %lld", rawValue)
		PostSyncAction.predicateExcludeCache[self] = predicate
		return predicate
	}
}

enum NotificationType: Int {
	case newComment, newPr, prMerged, prReopened, newMention, prClosed, newRepoSubscribed, newRepoAnnouncement, newPrAssigned, newStatus, newIssue, issueClosed, newIssueAssigned, issueReopened, assignedForReview, changesRequested, changesApproved, changesDismissed, newReaction
}

enum SortingMethod: Int {
	case creationDate, recentActivity, title
	static let reverseTitles = ["Youngest first", "Most recently active", "Reverse alphabetically"]
	static let normalTitles = ["Oldest first", "Inactive for longest", "Alphabetically"]

	init?(_ rawValue: Int) {
		self.init(rawValue: rawValue)
	}

	var normalTitle: String {
		return SortingMethod.normalTitles[rawValue]
	}

	var reverseTitle: String {
		return SortingMethod.reverseTitles[rawValue]
	}

	var field: String? {
		switch self {
		case .creationDate: return "createdAt"
		case .recentActivity: return "updatedAt"
		case .title: return "title"
		}
	}
}

enum HandlingPolicy: Int {
	case keepMine, keepMineAndParticipated, keepAll, keepNone
	static let labels = ["Keep Mine", "Keep Mine & Participated", "Keep All", "Don't Keep"]
	var name: String {
		return HandlingPolicy.labels[rawValue]
	}
	init?(_ rawValue: Int) {
		self.init(rawValue: rawValue)
	}
}

enum AssignmentPolicy: Int {
	case moveToMine, moveToParticipated, doNothing
	static let labels = ["Move To Mine", "Move To Participated", "Do Nothing"]
	var name: String {
		return AssignmentPolicy.labels[rawValue]
	}
	init?(_ rawValue: Int) {
		self.init(rawValue: rawValue)
	}
}

enum RepoDisplayPolicy: Int64 {
	case hide, mine, mineAndPaticipated, all
	static let labels = ["Hide", "Mine", "Participated", "All"]
	static let policies = [hide, mine, mineAndPaticipated, all]
	static let colors = [    COLOR_CLASS(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0),
	                         COLOR_CLASS(red: 0.7, green: 0.0, blue: 0.0, alpha: 1.0),
	                         COLOR_CLASS(red: 0.8, green: 0.4, blue: 0.0, alpha: 1.0),
	                         COLOR_CLASS(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)]
	var name: String {
		return RepoDisplayPolicy.labels[Int(rawValue)]
	}
	var color: COLOR_CLASS {
		return RepoDisplayPolicy.colors[Int(rawValue)]
	}
	var intValue: Int { return Int(rawValue) }

	init?(_ rawValue: Int64) {
		self.init(rawValue: rawValue)
	}
	init?(_ rawValue: Int) {
		self.init(rawValue: Int64(rawValue))
	}
}

enum DraftHandlingPolicy: Int {
    case nothing, display, hide
    static let labels = ["Do Nothing", "Display in Title", "Hide"]
}

enum RepoHidingPolicy: Int64 {
	case noHiding, hideMyAuthoredPrs, hideMyAuthoredIssues, hideAllMyAuthoredItems, hideOthersPrs, hideOthersIssues, hideAllOthersItems
	static let labels = ["No Filter", "Hide My PRs", "Hide My Issues", "Hide All Mine", "Hide Others PRs", "Hide Others Issues", "Hide All Others"]
	static let policies = [noHiding, hideMyAuthoredPrs, hideMyAuthoredIssues, hideAllMyAuthoredItems, hideOthersPrs, hideOthersIssues, hideAllOthersItems]
	static let colors = [    COLOR_CLASS.lightGray,
	                         COLOR_CLASS(red: 0.1, green: 0.1, blue: 0.5, alpha: 1.0),
	                         COLOR_CLASS(red: 0.1, green: 0.1, blue: 0.5, alpha: 1.0),
	                         COLOR_CLASS(red: 0.1, green: 0.1, blue: 0.5, alpha: 1.0),
	                         COLOR_CLASS(red: 0.5, green: 0.1, blue: 0.1, alpha: 1.0),
	                         COLOR_CLASS(red: 0.5, green: 0.1, blue: 0.1, alpha: 1.0),
	                         COLOR_CLASS(red: 0.5, green: 0.1, blue: 0.1, alpha: 1.0)]
	var name: String {
		return RepoHidingPolicy.labels[Int(rawValue)]
	}
	var color: COLOR_CLASS {
		return RepoHidingPolicy.colors[Int(rawValue)]
	}
	init?(_ rawValue: Int64) {
		self.init(rawValue: rawValue)
	}
	init?(_ rawValue: Int) {
		self.init(rawValue: Int64(rawValue))
	}
}

struct ApiRateLimits {
	let requestsRemaining, requestLimit: Int64
	let resetDate: Date?

	static func from(headers: [AnyHashable : Any]) -> ApiRateLimits {
		let date: Date?
		if let epochSeconds = headers["X-RateLimit-Reset"] as? String, let t = TimeInterval(epochSeconds) {
			date = Date(timeIntervalSince1970: t)
		} else {
			date = nil
		}
		return ApiRateLimits(requestsRemaining: Int64(S(headers["X-RateLimit-Remaining"] as? String)) ?? 10000,
		                     requestLimit: Int64(S(headers["X-RateLimit-Limit"] as? String)) ?? 10000,
		                     resetDate: date)
	}
	static var noLimits: ApiRateLimits {
		return ApiRateLimits(requestsRemaining: 10000, requestLimit: 10000, resetDate: nil)
	}
	var areValid: Bool {
		return requestsRemaining >= 0
	}
}

var currentAppVersion: String {
	return S(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
}

var versionString: String {
	let buildNumber = S(Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
	return "Version \(currentAppVersion) (\(buildNumber))"
}

#if os(OSX)

func openItem(_ url: URL) {
	openURL(url, using: Settings.defaultAppForOpeningItems.trim)
}

func openLink(_ url: URL) {
	openURL(url, using: Settings.defaultAppForOpeningWeb.trim)
}

func openURL(_ url: URL, using path: String) {
	if path.isEmpty {
		NSWorkspace.shared.open(url)
	} else {
		let appURL = URL(fileURLWithPath: path)
		do {
			try NSWorkspace.shared.open([url], withApplicationAt: appURL, options: [], configuration: [:])
		} catch {
			let a = NSAlert()
			a.alertStyle = .warning
			a.messageText = "Could not open this URL using '\(path)'"
			a.informativeText = error.localizedDescription
			a.runModal()
		}
	}
}

#endif

//////////////////////// Originally from tieferbegabt's post on https://forums.developer.apple.com/message/37935, with thanks!

extension String {
	func appending(pathComponent: String) -> String {
		let endSlash = hasSuffix("/")
		let firstSlash = pathComponent.hasPrefix("/")
		if endSlash && firstSlash {
			return appending(pathComponent.dropFirst())
		} else if (!endSlash && !firstSlash) {
			return appending("/\(pathComponent)")
		} else {
			return appending(pathComponent)
		}
	}
	var trim: String {
		return trimmingCharacters(in: .whitespacesAndNewlines)
	}
}

////////////////////// Notifications

extension Notification.Name {
    static let RefreshStarted = Notification.Name("RefreshStartedNotification")
    static let RefreshProcessing = Notification.Name("RefreshProcessingNotification")
    static let RefreshEnded = Notification.Name("RefreshEndedNotification")
    static let SyncProgressUpdate = Notification.Name("SyncProgressUpdateNotification")
    static let ApiUsageUpdate = Notification.Name("ApiUsageUpdateNotification")
    static let AppleInterfaceThemeChanged = Notification.Name("AppleInterfaceThemeChangedNotification")
    static let SettingsExported = Notification.Name("SettingsExportedNotification")
    static let MasterViewTitleChanged = Notification.Name("MasterViewTitleChangedNotification")
}
