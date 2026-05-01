import Foundation
import AppTrackingTransparency
import GoogleMobileAds
import UIKit

enum AdMobConfiguration {
    @MainActor private(set) static var isStarted = false
    @MainActor private static var isRequestingTrackingAuthorization = false

    @MainActor
    static func start() {
        guard !isStarted else {
            return
        }

        MobileAds.shared.start()
        isStarted = true
    }

    @MainActor
    static func requestTrackingAuthorizationIfNeeded() {
        guard
            !isRequestingTrackingAuthorization,
            ATTrackingManager.trackingAuthorizationStatus == .notDetermined,
            UIApplication.shared.applicationState == .active
        else {
            return
        }

        isRequestingTrackingAuthorization = true

        ATTrackingManager.requestTrackingAuthorization { _ in
            Task { @MainActor in
                isRequestingTrackingAuthorization = false
            }
        }
    }

    static var bannerAdUnitID: String? {
        guard
            let adUnitIDs = Bundle.main.object(forInfoDictionaryKey: "AdUnitID") as? [String: String],
            let bannerID = adUnitIDs["banner"]?.trimmingCharacters(in: .whitespacesAndNewlines),
            !bannerID.isEmpty,
            !bannerID.hasPrefix("$(")
        else {
            return nil
        }

        return bannerID
    }
}
