//
//  AppDelegate.swift
//  AuthenticiOS
//
//  Created by Greg Whatley on 12/28/17.
//  Copyright © 2017 Greg Whatley. All rights reserved.
//

import UIKit
import Firebase
import Foundation
import AVKit
import UserNotifications

enum AppMode {
    case Debug
    case TestFlight
    case Production
}

extension AppDelegate {
    private static let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    
    private static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var appMode: AppMode {
        if isDebug {
            return .Debug
        } else if isTestFlight {
            return .TestFlight
        } else {
            return .Production
        }
    }
}

extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10+ devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        self.log("UN willPresent: \(notification.request.content.title)")
        // Tell the system how to present the notification
        completionHandler([.alert, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        self.log("UN didReceive: \(response.notification.request.content.title)::\(response.actionIdentifier)")
        // Notify the app that a notification was received
        self.application(UIApplication.shared, didReceiveRemoteNotification: response.notification.request.content.userInfo)
        // The application(_:didReceiveRemoteNotification:) method populates AppDelegate.notificationAction
        // The AppDelegate.invokeNotificationAction(withViewController:) method will invoke the action (it contains a nil check)
        AppDelegate.invokeNotificationAction(withViewController: UIApplication.shared.windows[0].rootViewController!)
        // Notify the system that the notification was handled
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    // Register the app for notifications
    func configureNotifications(forApplication application: UIApplication) {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound], completionHandler: {_, _ in })
        application.registerForRemoteNotifications()
    }
    
    // Update the dev subscription once a Firebase token is received
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        AppDelegate.updateDevSubscription()
    }
    
    public static func updateDevSubscription() {
        if appMode != .Production {
            // If the app is running in debug or TestFlight mode, register for development notifications
            Messaging.messaging().subscribe(toTopic: "dev")
        } else {
            // Unsubscribe if the app is running in production
            Messaging.messaging().unsubscribe(fromTopic: "dev")
        }
    }
    
    public static func invokeNotificationAction(withViewController vc: UIViewController) {
        // Invoke the action if it is not nil
        notificationAction?.invoke(viewController: vc, origin: "notification", medium: "notification")
        // Clear it to prevent duplicate invocations
        notificationAction = nil
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        self.log("didReceiveRemoteNotification")
        let dict = NSDictionary(dictionary: userInfo.filter({ (arg) -> Bool in
            let (key, _) = arg
            return key as! String != "aps"
        }))
        guard dict.contains(where: { (k, _) -> Bool in
            return String(describing: k) == "type"
        }) else {
            AppDelegate.notificationAction = nil
            return
        }
        
        AppDelegate.notificationAction = ACButtonAction(dict: dict)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        self.log("didReceiveRemoteNotification completionHandler")
        self.application(application, didReceiveRemoteNotification: userInfo)
        completionHandler(.newData)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        self.log("Unable to register for notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        self.log("APNS token received: \(deviceToken)")
        // Subscribe to the main channel
        Messaging.messaging().subscribe(toTopic: "main")
    }
}

extension AppDelegate {
    func launchWithOptions(_ options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // If the app was launched via a shortcut, handle it
        if let shortcut = options?[.shortcutItem] as? UIApplicationShortcutItem {
            self.launchedItem = shortcut
            _ = respondAndClearShortcut()
            return false
        }
        return true
    }
    
    // Invokes the shortcut the sets it to nil to prevent duplicate invocations
    func respondAndClearShortcut() -> Bool {
        let response = respondToShortcut()
        self.launchedItem = nil
        return response
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        self.launchedItem = shortcutItem
        // Invokes the shortcut and sends the response to the handler
        completionHandler(respondAndClearShortcut())
    }
    
    public func respondToShortcut() -> Bool {
        // Keep track of whether the shortcut was invoked
        var handled = false
        // Ensure the there actually is a shortcut to invoke
        if let item = self.launchedItem {
            handled = true
            switch (item.type) {
            case "upcoming_events":
                // Load the events appearance and present the event collection view controller
                /*Database.database().reference().child("appearance").observeSingleEvent(of: .value, with: { appearanceSnapshot in
                    let appearance = ACAppearance(dict: appearanceSnapshot.value as! NSDictionary)
                    ACEventCollectionViewController.present(withAppearance: appearance.events)
                })*/
                ACTabBarViewController.setShortcutTabId("upcoming_events")
            case "tab":
                // Get the tab id from the shortcut info
                let tabId = item.userInfo!["id"] as? String
                ACTabBarViewController.setShortcutTabId(tabId)
            default:
                handled = false
            }
        }
        return handled
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var launchedItem: UIApplicationShortcutItem?
    private static var notificationAction: ACButtonAction? = nil
    public static var useDevelopmentDatabase = false
    var window: UIWindow?
    
    // Utility method to print and log to Firebase Analytics
    static func log(_ string: String) {
        print(string)
    }
    
    // Wrapper method for the static counterpart
    func log(_ string: String) {
        AppDelegate.log(string)
    }
    
    // Configure Firebase and settings
    func configureFirebase() {
        FirebaseApp.configure()
        Analytics.setAnalyticsCollectionEnabled(AppDelegate.appMode != .Debug)
        Database.database().isPersistenceEnabled = false
    }
    
    // Update the version displayed in the settings app
    func updateVersion() {
        let infoDict = Bundle.main.infoDictionary!
        UserDefaults.standard.set("\(infoDict["CFBundleShortVersionString"] as! String) build \(infoDict["CFBundleVersion"] as! String)", forKey: "sbVersion")
        UserDefaults.standard.synchronize()
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureFirebase()
        updateVersion()
        configureNotifications(forApplication: application)
        application.applicationIconBadgeNumber = 0
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: "playback"))
        } catch let error as NSError {
            self.log(error.localizedDescription)
        }
        
        UITabBarItem.appearance().setTitleTextAttributes([.font : UIFont(name: "Alpenglow-ExpandedRegular", size: UIFont.smallSystemFontSize - 2) ?? UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)], for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font : UIFont(name: "Alpenglow-ExpandedRegular", size: 16) ?? UIFont.systemFont(ofSize: 18)], for: .normal)
        // Launch the shortcut if there was one
        return launchWithOptions(launchOptions)
    }
    
    // Gets the most recently presented view controller (even modals)
    public static var topViewController: UIViewController {
        // Start at the root controller
        var vc = UIApplication.shared.windows[0].rootViewController!
        // Travel down the stack of presented view controllers until the end is found
        while (vc.presentedViewController != nil) {
            vc = vc.presentedViewController!
        }
        return vc
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0
        AppDelegate.updateDevSubscription()
        // Respond to shortcuts that occur while the app is in the background
        _ = respondAndClearShortcut()
    }
}
