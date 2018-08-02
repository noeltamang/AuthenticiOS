//
//  ACTabCollectionCollectionViewController.swift
//  AuthenticiOS
//
//  Created by Greg Whatley on 5/25/18.
//  Copyright © 2018 Greg Whatley. All rights reserved.
//

import UIKit
import Firebase

private let reuseIdentifier = "accvcell"
private let livestreamReuseIdentifier = "accvlscell"

extension UICollectionView {
    override open var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets.zero
    }
}

class ACTabCollectionViewController: UICollectionViewController {
    @IBAction func didRequestClose(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
        ACHomePageViewController.returnToFirstViewController()
    }
    
    @IBAction func showMoreOptions(_ sender: UIBarButtonItem) {
        present(UIActivityViewController(activityItems: [(Messaging.messaging().fcmToken ?? "<unavailable>") as NSString], applicationActivities: nil), animated: true, completion: nil)
        //self.show(ACAboutViewController(), sender: self)
        /*let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "About This App", style: .default, handler: {a in self.show(ACAboutViewController(), sender: self)}))
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: {a in ACButtonAction(type: "OpenURLAction", paramGroup: 0, params: ["url": UIApplicationOpenSettingsURLString]).invoke(viewController: self)}))
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancel)
        alert.preferredAction = cancel
        self.present(alert, animated: true, completion: nil)*/
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if !UserDefaults.standard.bool(forKey: "devNotifications") {
            self.navigationItem.rightBarButtonItem = nil
        }
        applyDefaultSettings()
        self.collectionView!.register(UINib(nibName: "ACCollectionViewCell", bundle: Bundle.main), forCellWithReuseIdentifier: reuseIdentifier)
        self.collectionView!.register(UINib(nibName: "ACLivestreamCollectionViewCell", bundle: Bundle.main), forCellWithReuseIdentifier: livestreamReuseIdentifier)
        collectionView?.collectionViewLayout = ACCollectionViewLayout(columns: 2, delegate: self)
        self.navigationController?.navigationBar.titleTextAttributes = [
            .kern: 3.5,
            .font: UIFont(name: "Effra", size: 21)!,
            .foregroundColor: UIColor.white
        ]
        self.collectionView?.refreshControl = UIRefreshControl()
        self.collectionView?.refreshControl?.attributedTitle = NSAttributedString(string: "PULL TO REFRESH", attributes: [
            .kern: 2.5,
            .font: UIFont(name: "Effra", size: 14)!,
            .foregroundColor: UIColor.black
            ])
        self.collectionView?.refreshControl?.tintColor = UIColor.black
        self.collectionView?.refreshControl?.addTarget(self, action: #selector(self.refreshData), for: .valueChanged)
        self.loadData(wasRefreshed: false)
    }

    private var appearance: ACAppearance?
    private var complete = false
    private var tabs: [ACTab] = []
    
    @objc public func refreshData() {
        loadData(wasRefreshed: true)
    }
    
    public func loadData(wasRefreshed: Bool) {
        self.tabs = []
        self.complete = false
        let trace = Performance.startTrace(name: "load tabs")
        if wasRefreshed {
            trace?.incrementMetric("refresh tabs", by: 1)
        }
        let appRef = Database.database().reference().child("appearance")
        appRef.keepSynced(true)
        appRef.observeSingleEvent(of: .value, with: { appearanceSnapshot in
            self.appearance = ACAppearance(dict: appearanceSnapshot.value as! NSDictionary)
            let tabsRef = Database.database().reference().child("tabs")
            tabsRef.keepSynced(true)
            tabsRef.observeSingleEvent(of: .value, with: {snapshot in
                let val = snapshot.value as? NSDictionary
                val?.forEach({(key, value) in
                    let tab = ACTab(dict: value as! NSDictionary)
                    if (!tab.getShouldBeHidden()) {
                        self.tabs.append(tab)
                    }
                })
                self.tabs.sort(by: { (a, b) in a.index < b.index })
                self.complete = true
                self.collectionView?.reloadData()
                self.collectionView?.collectionViewLayout.invalidateLayout()
                if #available(iOS 10.0, *) {
                    self.collectionView?.refreshControl?.endRefreshing()
                }
                var shortcuts = [UIApplicationShortcutItem]()
                shortcuts.append(UIMutableApplicationShortcutItem(type: "upcoming_events", localizedTitle: "Upcoming Events", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(type: .date), userInfo: nil))
                self.tabs.prefix(4).forEach({ t in
                    shortcuts.append(UIMutableApplicationShortcutItem(type: "tab", localizedTitle: t.title.localizedCapitalized, localizedSubtitle: nil, icon: nil, userInfo: ["id": t.id as NSSecureCoding]))
                })
                UIApplication.shared.shortcutItems = shortcuts
                trace?.stop()
            }) { error in
                self.present(UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert), animated: true)
                trace?.stop()
            }
        })
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.complete ? tabs.count + 2 : 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if (indexPath.item == 0) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: livestreamReuseIdentifier, for: indexPath) as! ACLivestreamCollectionViewCell
            cell.initialize(withViewController: self)
            cell.layoutIfNeeded()
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ACCollectionViewCell
        if (indexPath.item == 1) {
            cell.initialize(forUpcomingEvents: self.appearance!.events, withViewController: self)
        } else if !self.tabs.isEmpty {
            cell.initialize(forTab: self.tabs[indexPath.item - 2], withViewController: self)
        }
        cell.layoutIfNeeded()
        return cell
    }

}

extension ACTabCollectionViewController : ACCollectionViewLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView, sizeForCellAtIndexPath indexPath: IndexPath) -> CGSize {
        if indexPath.item == 0 {
                return CGSize(width: view.frame.width, height: 60.0)
        }
        let isLeftColumn = indexPath.section == 0
        var tabsInColumn = (isLeftColumn ? self.tabs.filter({t in t.index % 2 == 0}) : self.tabs.filter({t in t.index % 2 > 0})).count
        if !isLeftColumn {
            tabsInColumn += 1
        }
        let fill = (isLeftColumn ? self.appearance!.tabs.fillLeft : self.appearance!.tabs.fillRight) && tabsInColumn <= 4
        let availableHeight = UIScreen.main.bounds.height - UIApplication.shared.statusBarFrame.height - navigationController!.navigationBar.frame.height - 60
        if indexPath.item == 1 {
            let app = appearance!.events
            if fill {
                return CGSize(width: view.frame.width / 2, height: availableHeight / CGFloat(tabsInColumn))
            }
            let adjustedWidth = view.frame.width / 2
            let ratio = CGFloat(app.header.width) / CGFloat(app.header.height == 0 ? 1 : app.header.height)
            let adjustedHeight = adjustedWidth / ratio
            return CGSize(width: adjustedWidth, height: adjustedHeight)
        }
        guard !self.tabs.isEmpty else {
            return CGSize.zero
        }
        let tab = self.tabs[indexPath.item - 2]
        if fill {
            return CGSize(width: view.frame.width / 2, height: availableHeight / CGFloat(tabsInColumn))
        }
        let adjustedWidth = view.frame.width / 2
        let ratio = CGFloat(tab.header.width) / CGFloat(tab.header.height == 0 ? 1 : tab.header.height)
        let adjustedHeight = adjustedWidth / ratio
        return CGSize(width: adjustedWidth, height: adjustedHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, columnNumberForCellAtIndexPath indexPath: IndexPath) -> Int {
        if indexPath.item == 0 {
            return 0
        }
        if indexPath.item == 1 {
            return 1
        }
        return self.tabs[indexPath.item - 2].index % 2 == 0 ? 0 : 1
    }
}
