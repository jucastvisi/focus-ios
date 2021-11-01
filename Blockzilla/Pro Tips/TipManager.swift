/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import LocalAuthentication

class TipManager {
    
    @UserDefault(key: TipKey.releaseTip, defaultValue: true)
    static var releaseTip: Bool
    
    @UserDefault(key: TipKey.shortcutsTip, defaultValue: true)
    static var shortcutsTip: Bool
    
    @UserDefault(key: TipKey.sitesNotWorkingTip, defaultValue: true)
    static var sitesNotWorkingTip: Bool
    
    @UserDefault(key: TipKey.siriFavoriteTip, defaultValue: true)
    static var siriFavoriteTip: Bool
    
    @UserDefault(key: TipKey.biometricTip, defaultValue: true)
    static var biometricTip: Bool
    
    @UserDefault(key: TipKey.shareTrackersTip, defaultValue: true)
    static var shareTrackersTip: Bool
    
    @UserDefault(key: TipKey.siriEraseTip, defaultValue: true)
    static var siriEraseTip: Bool
    
    @UserDefault(key: TipKey.requestDesktopTip, defaultValue: true)
    static var requestDesktopTip: Bool
    

    struct Tip: Equatable {
        enum ScrollDestination {
            case siri
            case biometric
            case siriFavorite
        }
        
        enum Action {
            case visit(topic: SupportTopic)
            case showSettings(destination: ScrollDestination)
        }
        
        let title: String
        let description: String?
        let identifier: String
        let action: Action?
        let canShow: () -> Bool

        init(
            title: String,
            description: String? = nil,
            identifier: String,
            action: Action? = nil,
            canShow: @escaping () -> Bool
        ) {
            self.title = title
            self.identifier = identifier
            self.description = description
            self.action = action
            self.canShow = canShow
        }

        static func == (lhs: Tip, rhs: Tip) -> Bool {
            return lhs.identifier == rhs.identifier
        }
    }

    enum TipKey {
        static let releaseTip = "releaseTip"
        static let shortcutsTip = "shortcutsTip"
        static let sitesNotWorkingTip = "sitesNotWorkingTip"
        static let biometricTip = "biometricTip"
        static let siriFavoriteTip = "siriFavoriteTip"
        static let shareTrackersTip = "shareTrackersTip"
        static let requestDesktopTip = "requestDesktopTip"
        static let siriEraseTip = "siriEraseTip"
    }

    static let shared = TipManager()
    private var tips: [Tip] {
        var tips = [
            releaseTip,
            shortcutsTip,
            sitesNotWorkingTip,
            requestDesktopTip,
            siriFavoriteTip,
            siriEraseTip,
            shareTrackersTip
        ]
        if laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            tips.append(biometricTip)
        }
        return tips
    }
    
    private var availableTips: [Tip] {
        guard Settings.getToggle(.showHomeScreenTips) else { return [] }
        return tips.filter { $0.canShow() }
    }
    
    private let laContext = LAContext()

    private init() { }

    private lazy var releaseTip = Tip(
        title: String(format: .releaseTipTitle, AppInfo.config.productName),
        description: String(format: .releaseTipDescription, AppInfo.config.productName),
        identifier: TipKey.releaseTip,
        action: .visit(topic: .whatsNew),
        canShow: { TipManager.releaseTip }
    )
    
    private lazy var shortcutsTip = Tip(
        title: .shortcutsTipTitle,
        description: String(format: .shortcutsTipDescription, AppInfo.config.productName),
        identifier: TipKey.shortcutsTip,
        canShow: { TipManager.shortcutsTip }
    )

    private lazy var sitesNotWorkingTip = Tip(
        title: .sitesNotWorkingTipTitle,
        description: .sitesNotWorkingTipDescription,
        identifier: TipKey.sitesNotWorkingTip,
        canShow: { TipManager.sitesNotWorkingTip }
    )

    private lazy var biometricTip: Tip = {
        let description: String = laContext.biometryType == .faceID
            ? .biometricTipFaceIdDescription
            : .biometricTipTouchIdDescription
        
        return Tip(
            title: String(format: .biometricTipTitle, AppInfo.productName),
            description: description,
            identifier: TipKey.biometricTip,
            action: .showSettings(destination: .biometric),
            canShow: { TipManager.biometricTip }
        )
    }()

    private lazy var requestDesktopTip = Tip(
        title: .requestDesktopTipTitle,
        description: .requestDesktopTipDescription,
        identifier: TipKey.requestDesktopTip,
        canShow: { TipManager.requestDesktopTip }
    )

    private lazy var siriFavoriteTip = Tip(
        title: .siriFavoriteTipTitle,
        description: .siriFavoriteTipDescription,
        identifier: TipKey.siriFavoriteTip,
        action: .showSettings(destination: .siri),
        canShow: { TipManager.siriFavoriteTip && self.isiOS12 }
    )

    private lazy var siriEraseTip = Tip(
        title: String(format: .siriEraseTipTitle, AppInfo.productName),
        description: .siriEraseTipDescription,
        identifier: TipKey.siriEraseTip,
        action: .showSettings(destination: .siriFavorite),
        canShow: { TipManager.siriEraseTip && self.isiOS12 }
    )

    /// Return a string representing the trackers tip. It will include the current number of trackers blocked, formatted as a decimal.
    func shareTrackersDescription() -> String {
        let numberOfTrackersBlocked = NSNumber(integerLiteral: UserDefaults.standard.integer(forKey: BrowserViewController.userDefaultsTrackersBlockedKey))
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return String(format: .shareTrackersTipDescription, formatter.string(from: numberOfTrackersBlocked) ?? "0")
    }
    
    private var shareTrackersTip: Tip {
        Tip(
            title: String(format: .shareTrackersTipTitle, AppInfo.productName),
            description: shareTrackersDescription(),
            identifier: TipKey.shareTrackersTip,
            canShow: { UserDefaults.standard.integer(forKey: BrowserViewController.userDefaultsTrackersBlockedKey) >= 10 }
        )
    }

    func fetchFirstTip() -> Tip? { availableTips.first }
    
    private var isiOS12: Bool {
        guard #available(iOS 12.0, *) else { return false }
        return true
    }
    
    func getTip(after: Tip) -> Tip? {
        if let index = availableTips.firstIndex(where: { $0.identifier == after.identifier }) {
                let after = index == availableTips.count - 1 ? availableTips[0] : availableTips[index + 1]
                return after
            }
        return nil
    }
    
    func getTip(before: Tip) -> Tip? {
        if let index = availableTips.firstIndex(where: { $0.identifier == before.identifier }) {
            let before = index == 0 ? availableTips.last : availableTips[index - 1]
            return before
        }
        return nil
    }
    
    var numberOfTips: Int { availableTips.count }
    
    func currentIndex(for tip: Tip) -> Int {
        if let index = availableTips.firstIndex(where: { $0.identifier == tip.identifier }) {
            return index
        }
        return 0
    }
}

// MARK: - Home Screen Tips Strings

fileprivate extension String {
    
    static let releaseTipTitle = NSLocalizedString("Tip.Release.Title", value: "Why yes, we do have a fresh new look!", comment: "Text for a label that indicates the title for release tip.")
    static let releaseTipDescription = NSLocalizedString("Tip.Release.Description", value: "Read more about this and other updates to %@.", comment: "Text for a label that indicates the description for release tip.")
    static let shortcutsTipTitle = NSLocalizedString("Tip.Shortcuts.Title", value: "Create shortcuts to the sites you visit most:", comment: "Text for a label that indicates the title for shortcuts tip.")
    static let shortcutsTipDescription = NSLocalizedString("Tip.Shortcuts.Description", value: "Select Add to Shortcuts from the %@ menu", comment: "Text for a label that indicates the description for shortcuts tip.")
    static let sitesNotWorkingTipTitle = NSLocalizedString("Tip.SitesNotWorking.Title", value: "Site missing content or acting strange?", comment: "Text for a label that indicates the title for sites not working tip.")
    static let sitesNotWorkingTipDescription = NSLocalizedString("Tip.SitesNotWorking.Description", value: "Try turning off Tracking Protection", comment: "Text for a label that indicates the description for sites not working tip.")
    static let biometricTipTitle = NSLocalizedString("Tip.Biometric.Title", value: "Lock %@ when a site is open:", comment: "Text for a label that indicates the title for biometric tip.")
    static let biometricTipFaceIdDescription = NSLocalizedString("Tip.BiometricFaceId.Description", value: "Turn on Face ID", comment: "Text for a label that indicates the description for biometric Face ID tip.")
    static let biometricTipTouchIdDescription = NSLocalizedString("Tip.BiometricTouchId.Description", value: "Turn on Touch ID", comment: "Text for a label that indicates the description for biometric Touch ID tip.")
    static let requestDesktopTipTitle = NSLocalizedString("Tip.RequestDesktop.Title", value: "Want to see the full desktop version of a site?", comment: "Text for a label that indicates the title for request desktop tip.")
    static let requestDesktopTipDescription = NSLocalizedString("Tip.RequestDesktop.Description", value: "Page Actions > Request Desktop Site", comment: "Text for a label that indicates the description for request desktop tip.")
    static let siriFavoriteTipTitle = NSLocalizedString("Tip.SiriFavorite.Title", value: "“Siri, open my favorite site.”", comment: "Text for a label that indicates the title for siri favorite tip.")
    static let siriFavoriteTipDescription = NSLocalizedString("Tip.SiriFavorite.Description", value: "Add Siri shortcut", comment: "Text for a label that indicates the description for siri favorite tip.")
    static let siriEraseTipTitle = NSLocalizedString("Tip.SiriErase.Title", value: "“Siri, erase my %@ session.”", comment: "Text for a label that indicates the title for siri erase tip.")
    static let siriEraseTipDescription = NSLocalizedString("Tip.SiriErase.Description", value: "Add Siri shortcut", comment: "Text for a label that indicates the description for siri erase tip.")
    static let shareTrackersTipTitle = NSLocalizedString("Tip.ShareTrackers.Title", value: "You browse. %@ blocks.", comment: "Text for a label that indicates the title for share trackers tip.")
    static let shareTrackersTipDescription = NSLocalizedString("Tip.ShareTrackers.Description", value: "%@ trackers blocked so far", comment: "Text for a label that indicates the description for share trackers tip.")
}