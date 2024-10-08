import Foundation
import SwiftUI
import UIKit
import os

// The Swift Programming Language
// https://docs.swift.org/swift-book
@available(iOS 14.0, *)
@MainActor
public class Flock: NSObject {
    private static var flock: Flock?
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Flock.self)
    )
    
    public private(set) static var isInitialized = false
    
    private let publicAccessKey: String
    private let campaignId: String
    private let apiClient: APIClient
    private var webViewController: WebViewController?
    private var customer: Customer?
    
    private init(publicAccessKey: String, campaignId: String, overrideApiURL: String? = nil) {
        self.publicAccessKey = publicAccessKey
        self.campaignId = campaignId
        self.apiClient = APIClient(apiKey: self.publicAccessKey, baseURL: overrideApiURL)
    }
    
    public static var shared: Flock {
        guard let flock = flock else {
            logger.warning("FlockSDK has not been configured. Please call FlockSDK.configure()")
            assertionFailure("FlockSDK has not been configured. Please call FlockSDK.configure()")
            return Flock(publicAccessKey: "", campaignId: "")
        }
        return flock
    }
    
    @discardableResult
    public static func configure(
        publicAccessKey: String,
        campaignId: String,
        overrideApiURL: String? = nil
    ) -> Flock {
        guard flock == nil else {
            logger.warning("FlockSDK has already been configured. Please call FlockSDK.configure() only once")
            return shared
        }
        
        flock = Flock(publicAccessKey: publicAccessKey, campaignId: campaignId, overrideApiURL: overrideApiURL)
        isInitialized = true
        
        flock?.ping()
        
        return shared
    }
    
    /**
     Ping the server to make sure the integration is working
     */
    public func ping() -> Void {
        Task {
            do {
                try await self.apiClient.ping(campaignId: self.campaignId)
            } catch {
                Flock.logger.error("Error pinging server: \(error)")
            }
        }
    }
    
    /**
     Identify customers to keep a record in Flock
     */
    public func identify(externalUserId: String, email: String, name: String?) -> Void {
        Task {
            do {
                let identifyRequest = IdentifyRequest(externalUserId: externalUserId, email: email, name: name, campaignId: self.campaignId)
                customer = try await self.apiClient.identify(identifyRequest: identifyRequest)
                
                // Preload Referral page
                if let customer = customer {
                    webViewController = WebViewController(url: getReferURL(for: customer))
                    webViewController?.loadViewIfNeeded()
                }
            } catch {
                Flock.logger.error("Error identifying customer: \(error)")
            }
        }
    }
    
    /**
     Open Referral Page
     */
    public func openReferralView(style: WebViewPresentationStyle? = .fullscreen) {
        if let webViewController = self.webViewController, let topViewController = UIApplication.shared.topMostViewController() {
            if style == .modal {
                topViewController.present(webViewController, animated: true, completion: nil)
            } else if let navigationController = topViewController.navigationController {
                navigationController.pushViewController(webViewController, animated: true)
            } else if let tabBarController = topViewController as? UITabBarController,
                      let selectedNavController = tabBarController.selectedViewController as? UINavigationController {
                selectedNavController.pushViewController(webViewController, animated: true)
            } else {
                webViewController.modalPresentationStyle = .overFullScreen
                topViewController.present(webViewController, animated: true, completion: nil)
            }
        }
    }
    
    private func getReferURL(for customer: Customer) -> URL {
        let queryItems = [URLQueryItem(name: "customer_id", value: customer.id), URLQueryItem(name: "key", value: self.publicAccessKey)]
        
        var urlComps = URLComponents(string: "http://localhost:4200/refer")!
        urlComps.queryItems = queryItems
        
        return urlComps.url!
    }
}
