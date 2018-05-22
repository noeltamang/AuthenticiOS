//
//  ViewController.swift
//  AuthenticiOS
//
//  Created by Greg Whatley on 12/28/17.
//  Copyright © 2017 Greg Whatley. All rights reserved.
//

import UIKit
import Firebase

class ACHomeViewController: UIViewController {
    
    @IBOutlet weak var buttonConstraint: NSLayoutConstraint!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var logo: UIImageView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    @objc public func devNotifications() {
        let settingsAlert = UIAlertController(title: "Development Notifications", message: "Development notifications are for internal testing use only.  Interacting with them may cause instability.\n\n/topics/dev", preferredStyle: .actionSheet)
        settingsAlert.addAction(UIAlertAction(title: "Subscribe", style: .destructive, handler: { _ in
            Messaging.messaging().subscribe(toTopic: "dev")
            let message = UIAlertController(title: "Subscribed to /topics/dev", message: nil, preferredStyle: .alert)
            message.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
            message.preferredAction = message.actions.first
            self.present(message, animated: true, completion: nil)
        }))
        settingsAlert.addAction(UIAlertAction(title: "Unsubscribe", style: .default, handler: { _ in
            Messaging.messaging().unsubscribe(fromTopic: "dev")
            let message = UIAlertController(title: "Unsubscribed from /topics/dev", message: nil, preferredStyle: .alert)
            message.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
            message.preferredAction = message.actions.first
            self.present(message, animated: true, completion: nil)
        }))
        settingsAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(settingsAlert, animated: true, completion: nil)
    }
    
    private func displayMainUI() {
        self.logo.isUserInteractionEnabled = true
        self.logo.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.devNotifications)))
        AppDelegate.invokeNotificationAction(withViewController: self)
        UIView.animate(withDuration: 0.25, delay: 0.1, options: .curveEaseInOut, animations: {
            self.indicator.alpha = 0
            self.logo.alpha = 1
        }) { b in
            UIView.animate(withDuration: 0.5, delay: 0.1, options: .curveEaseInOut, animations: {
                self.buttonConstraint.constant = 75
                self.view.layoutIfNeeded()
            }) { b in
                UIView.animate(withDuration: 0.25, animations: {
                    self.button.alpha = 1
                })
            }
        }
    }
    
    private func checkForUpdate() {
        let versionRef = Database.database().reference(withPath: "versions/ios")
        versionRef.keepSynced(true)
        versionRef.observeSingleEvent(of: .value, with: { snapshot in
            let value = snapshot.value as! Int
            print("LOCAL UPDATE CODE: \(VersionInfo.Update)")
            print("REMOTE UPDATE CODE: \(value)")
            if value > VersionInfo.Update {
                let alert = UIAlertController(title: "Update Available", message: "An update is available for the Authentic City Church app.  We highly recommend that you update to avoid missing out on new features.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Not Now", style: .default, handler: { _ in self.displayMainUI() }))
                alert.addAction(UIAlertAction(title: "Update", style: .default, handler: { _ in UIApplication.shared.openURL(URL(string: "itms-apps://phobos.apple.com/WebObjects/MZStore.woa/wa/viewSoftwareUpdate?id=1164541935&mt=8")!)
                    self.displayMainUI()
                }))
                self.present(alert, animated: true, completion: nil)
            } else {
                self.displayMainUI()
            }
        })
    }
    
    private func displayCheckForUpdate() {
        UIView.animate(withDuration: 0.25, delay: 0.1, options: .curveEaseInOut, animations: {
            self.indicator.alpha = 1
        }) { b in
            Reachability.getConnectionStatus(completionHandler: { connected in
                print("CONNECTED TO NETWORK: \(connected)")
                if connected {
                    self.checkForUpdate()
                } else {
                    self.displayMainUI()
                }
            })
        }
    }
    
    private func preInitialize() {
        self.button.alpha = 0
        self.logo.alpha = 0
        self.indicator.alpha = 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preInitialize()
        UIView.animate(withDuration: 0.001, animations: {
            self.view.layoutIfNeeded()
        }) { b in
            self.displayCheckForUpdate()
        }
    }
}
