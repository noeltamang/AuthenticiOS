//
//  ACCollectionViewCell.swift
//  AuthenticiOS
//
//  Created by Greg Whatley on 5/25/18.
//  Copyright © 2018 Greg Whatley. All rights reserved.
//

import UIKit
import FirebaseUI
import FirebaseStorage

class ACCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var tintView: UIView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    private var text: String = ""
    private var imageResource = ACImageResource()
    
    private var eventsAppearance: ACAppearance.Events!
    private var viewController: UIViewController!
    private var tab: ACTab!
    private var event: ACEvent!
    private var action: ACButtonAction!
    private var tint: Bool = true
    
    @objc public func presentUpcomingEvents() {
        ACEventCollectionViewController.present(withAppearance: eventsAppearance)
    }
    
    @objc public func presentTab() {
        ACTabViewController.present(tab: self.tab, origin: "home:tile:/tabs/\(self.tab.id)", medium: "user")
    }
    
    @objc public func presentEvent() {
        ACEventViewController.present(event: self.event, isPlaceholder: false, origin: "home:tile:/events/\(self.event.id)", medium: "user")
    }
    
    @objc public func presentEventPlaceholder() {
        guard let placeholder = event as? ACEventPlaceholder else {return}
        if placeholder.action != nil {
            placeholder.action!.invoke(viewController: self.viewController, origin: "home:tile:/events/\(self.event.id)", medium: "user")
        } else if placeholder.elements?.count ?? 0 > 0 {
            self.presentEvent()
        }
    }
    
    @objc public func invokeAction() {
        action.invoke(viewController: viewController, origin: "home:tile:/tabs/\(self.tab.id)", medium: "user")
    }
    
    public func initialize(forUpcomingEvents appearance: ACAppearance.Events, withViewController vc: UIViewController) {
        self.text = appearance.title
        self.imageResource = appearance.header
        self.eventsAppearance = appearance
        self.viewController = vc
        self.accessibilityLabel = "View Upcoming Events"
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.presentUpcomingEvents)))
        self.initialize()
    }
    
    public func initialize(forTab tab: ACTab, withViewController vc: UIViewController) {
        self.text = tab.title
        self.imageResource = tab.header
        self.tab = tab
        self.viewController = vc
        if tab.action == nil {
            self.accessibilityLabel = "Open page: \(tab.title)"
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.presentTab)))
        } else {
            self.accessibilityLabel = "\(tab.action!.accessibilityLabel): \(tab.title)"
            self.action = tab.action!
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.invokeAction)))
        }
        self.initialize()
    }
    
    public func initialize(forEvent event: ACEvent, withViewController vc: UIViewController) {
        self.text = event.title
        self.imageResource = event.header
        self.event = event
        self.viewController = vc
        self.accessibilityLabel = "View event details: \(event.title)"
        self.tint = !event.hideTitle
        if event is ACEventPlaceholder {
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.presentEventPlaceholder)))
        } else {
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.presentEvent)))
        }
        self.initialize()
    }
    
    public func initialize(withTitle title: String, header: ACImageResource, action: ACButtonAction, viewController vc: UIViewController) {
        self.text = title
        self.imageResource = header
        self.viewController = vc
        self.action = action
        self.accessibilityLabel = "\(action.accessibilityLabel): \(title)"
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.invokeAction)))
        self.initialize()
    }
    
    private func initialize() {
        let rand = CGFloat(drand48())
        self.isUserInteractionEnabled = true
        self.accessibilityTraits = [.allowsDirectInteraction, .button]
        self.isAccessibilityElement = true
        self.backgroundColor = UIColor(red: rand, green: rand, blue: rand, alpha: 1)
        if (self.tint) {
            self.indicator.alpha = 0
            self.indicator.isHidden = true
        } else {
            self.indicator.isHidden = false
            self.indicator.color = UIColor(red: 1 - rand, green: 1 - rand, blue: 1 - rand, alpha: 1)
        }
        image.alpha = 0
        self.subviews.forEach { v in
            if let l = v as? ACInsetLabel {
                l.removeFromSuperview()
            }
        }
        imageResource.load(intoImageView: image, fadeIn: true, setSize: false, scaleDownLargeImages: true, completion: {
            UIView.animate(withDuration: 0.3, animations: {
                self.backgroundColor = UIColor.black
                self.indicator.isHidden = true
            }, completion: {_ in self.indicator.stopAnimating()})
        })
        self.tintView.alpha = self.tint ? 1 : 0
        let label = (ACElement.createTitle(text: self.tint ? self.text : "", alignment: "center", border: false, size: 18, color: UIColor.white, bold: true) as! UIStackView).arrangedSubviews[0]
        self.addSubview(label)
        self.constraints.forEach({c in self.removeConstraint(c)})
        self.addConstraints([
            NSLayoutConstraint(item: image!, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: image!, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: label, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: label, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: label, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: label, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0)
            ])
        self.setNeedsLayout()
    }
}
