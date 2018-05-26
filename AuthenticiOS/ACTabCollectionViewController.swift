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

class ACTabCollectionViewController: UICollectionViewController {
    public var didStartFromSwipe = false
    
    @IBAction func didRequestClose(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
        if (didStartFromSwipe) {
            ACHomePageViewController.returnToFirstViewController()
        }
    }
    
    @IBAction func showMoreOptions(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "About This App", style: .default, handler: {a in self.show(ACAboutViewController(), sender: self)}))
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: {a in AuthenticButtonAction(type: "OpenURLAction", paramGroup: 0, params: ["url": UIApplicationOpenSettingsURLString]).invoke(viewController: self)}))
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancel)
        alert.preferredAction = cancel
        self.present(alert, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Utilities.applyTintColor(to: self)
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.register(UINib(nibName: "ACCollectionViewCell", bundle: Bundle.main), forCellWithReuseIdentifier: reuseIdentifier)
        (self.collectionViewLayout as! UICollectionViewFlowLayout).sectionInset = UIEdgeInsets.zero
        if #available(iOS 10.0, *) {
            self.collectionView?.refreshControl = UIRefreshControl()
            self.collectionView?.refreshControl?.attributedTitle = NSAttributedString(string: "PULL TO REFRESH", attributes: [
                .kern: 1.5,
                .font: UIFont(name: "Effra", size: 14)!,
                .foregroundColor: UIColor.white
                ])
            self.collectionView?.refreshControl?.tintColor = UIColor.white
            self.collectionView?.refreshControl?.addTarget(self, action: #selector(self.loadData), for: .valueChanged)
        }
        self.loadData()
    }

    private var appearance: AuthenticAppearance?
    private var complete = false
    private var tabs: [AuthenticTab] = []
    
    @objc public func loadData() {
        self.tabs = []
        self.complete = false
        let appRef = Database.database().reference().child("appearance")
        appRef.keepSynced(true)
        appRef.observeSingleEvent(of: .value, with: { appearanceSnapshot in
            self.appearance = AuthenticAppearance(dict: appearanceSnapshot.value as! NSDictionary)
            let tabsRef = Database.database().reference().child("tabs")
            tabsRef.keepSynced(true)
            tabsRef.observeSingleEvent(of: .value, with: {snapshot in
                let val = snapshot.value as? NSDictionary
                val?.forEach({(key, value) in
                    let tab = AuthenticTab(dict: value as! NSDictionary)
                    if (!tab.getShouldBeHidden()) {
                        self.tabs.append(tab)
                    }
                    self.tabs.sort(by: { (a, b) in a.index < b.index })
                    self.complete = true
                    self.collectionView?.reloadData()
                    if #available(iOS 10.0, *) {
                        self.collectionView?.refreshControl?.endRefreshing()
                    }
                    var shortcuts = [UIApplicationShortcutItem]()
                    shortcuts.append(UIMutableApplicationShortcutItem(type: "upcoming_events", localizedTitle: "Upcoming Events", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(type: .date), userInfo: nil))
                    self.tabs.prefix(4).forEach({ t in
                        shortcuts.append(UIMutableApplicationShortcutItem(type: "tab", localizedTitle: t.title.localizedCapitalized, localizedSubtitle: nil, icon: nil, userInfo: ["id": t.id]))
                    })
                    UIApplication.shared.shortcutItems = shortcuts
                })
            }) { error in self.present(UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert), animated: true) }
        })
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        return self.complete ? tabs.count + 1 : 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ACCollectionViewCell
        if (indexPath.item == 0) {
            cell.initialize(forUpcomingEvents: self.appearance!.events)
        } else {
            cell.initialize(forTab: self.tabs[indexPath.item - 1])
        }
        cell.layoutIfNeeded()
        return cell
    }

}

extension ACTabCollectionViewController : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = view.frame.width / 2
        return CGSize(width: width, height: 1.5*width)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets.zero
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}
