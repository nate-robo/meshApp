//
//  FirstViewController.swift
//  meshApp
//
//  Created by Nathan on 3/3/16.
//  Copyright © 2016 Nathan. All rights reserved.
//

import UIKit
import MultipeerConnectivity

//Class that shows available peers and handles the UI interaction to toggle connectivity, display advertising peers, and invite peers to chat
class FirstViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MPCManagerDelegate {
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    var isAdvertising: Bool! //Used to toggle whether or not device is discoverable
    
    @IBOutlet weak var peerTable: UITableView!

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.tabBarController?.tabBar.layer.borderWidth = 0.50
        self.tabBarController?.tabBar.layer.borderColor = UIColor.clearColor().CGColor
        
        peerTable.delegate = self
        peerTable.dataSource = self
  
        appDelegate.mpcManager.delegate = self
        appDelegate.mpcManager.browser.startBrowsingForPeers()
        appDelegate.mpcManager.advertiser.startAdvertisingPeer()
        
        isAdvertising = true
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //Start-Stop Advertising Toggle
    //When toggle button is tapped present an alert view to allow the user to toggle
    @IBAction func toggleAdvertising(sender: AnyObject) {
        
        let actionSheet = UIAlertController(title: "", message: "Change Visibility", preferredStyle: UIAlertControllerStyle.ActionSheet)
        
        var actionTitle: String
        if isAdvertising == true {
            actionTitle = "Make me visible"
        }
        else {
            actionTitle = "Make me anonymous"
        }
        
        let visibilityAction: UIAlertAction = UIAlertAction(title: actionTitle, style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            if self.isAdvertising == true {
                self.appDelegate.mpcManager.advertiser.stopAdvertisingPeer()
            }
            else {
                self.appDelegate.mpcManager.advertiser.startAdvertisingPeer()
            }
            
            self.isAdvertising = !self.isAdvertising
            
        }
        
        let cancelAction = UIAlertAction(title:"Cancel", style: UIAlertActionStyle.Cancel) { (alertAction) -> Void in
            
        }
        
        actionSheet.addAction(visibilityAction)
        actionSheet.addAction(cancelAction)
        self.presentViewController(actionSheet, animated: true, completion: nil)
        
    }
    
    
    
    /*
    Once a connection is made, segue to the chat view
    */
    func connectedWithPeer(peerID: MCPeerID) {
        NSOperationQueue.mainQueue().addOperationWithBlock { () -> Void in
            self.performSegueWithIdentifier("idSegueChat", sender: self)
        }
    }
    
    /*
    Present the user with an alert to either accept or decline an invitation from another peer to chat
    Notify delegate of accept or decline
    */
    func invitationReceived(fromPeer: String) {
        let alert = UIAlertController(title: "", message: "\(fromPeer) wants to chat with you.", preferredStyle: UIAlertControllerStyle.Alert)
        
        let accept: UIAlertAction = UIAlertAction(title: "Accept", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            self.appDelegate.mpcManager.invitationHandler(true, self.appDelegate.mpcManager.session)
        }
        
        let decline: UIAlertAction = UIAlertAction(title:"Decline", style: UIAlertActionStyle.Cancel) { (alertAction) -> Void in
            self.appDelegate.mpcManager.invitationHandler(false, self.appDelegate.mpcManager.session) //suspect
        }
        
        alert.addAction(accept)
        alert.addAction(decline)

        NSOperationQueue.mainQueue().addOperationWithBlock { () -> Void in
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
    }
    
    //Fix table after data change
    func foundPeer() {
        
        peerTable.reloadData()
    }
    
    //Fix table after data
    func lostPeer() {
        peerTable.reloadData()
    }
    
    // UITableView Methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return appDelegate.mpcManager.foundPeers.count
    }
    
    /*
    Display advertising peers in table
    */
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("idCellPeer")! as UITableViewCell
        cell.textLabel?.text = appDelegate.mpcManager.foundPeers[indexPath.row].displayName
        return cell
    }
    
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 60.0
    }
    
    /*
    When user taps row, invite the peer to join a chat session
    */
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let selectedPeer = appDelegate.mpcManager.foundPeers[indexPath.row] as MCPeerID!
        appDelegate.mpcManager.browser.invitePeer(selectedPeer, toSession: appDelegate.mpcManager.session, withContext: nil, timeout: 30)
        
    }


}

