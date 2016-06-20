//
//  chatControllerViewController.swift
//  meshApp
//
//  Created by Nathan on 3/3/16.
//  Copyright © 2016 Nathan. All rights reserved.
//

import UIKit
import MultipeerConnectivity


//Class that handles the session and chat session
class chatControllerViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var textChat: UITextField!
    
    @IBOutlet weak var tableChat: UITableView!
    
    //Messages in the session chat
    var messagesArray: [Dictionary<String, String>] = []
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    @IBOutlet weak var textChatBtm: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        tableChat.delegate = self
        tableChat.dataSource = self
        
        tableChat.estimatedRowHeight = 60.0
        tableChat.rowHeight = UITableViewAutomaticDimension
        
        textChat.delegate = self
        
        //Custom Method to handle notifying peers in the session that data has been sent and needs to update the app accordingly
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.handleMPCReceivedDataWithNotification), name: "receivedMPCDataNotification", object: nil)
        //CUstom method to handle notifying peers in the session an individual disconnected and react accordingly
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.handleChatLoss), name: "chatLossNotification", object: nil)
        
        //Keyboard methods for propper UItextfield shift when keyboard expands and contracts
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(chatControllerViewController.animateWithKeyboard(_:)), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(chatControllerViewController.animateWithKeyboard(_:)), name: UIKeyboardWillHideNotification, object: nil)
        }
    
    func animateWithKeyboard(notification: NSNotification) {
        
        // Based on both Apple's docs and personal experience,
        // I assume userInfo and its documented keys are available.
        // If you'd like, you can remove the forced unwrapping and add your own default values.
        
        let userInfo = notification.userInfo!
        let keyboardHeight = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue().height
        let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as! Double
        let curve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as! UInt
        let moveUp = (notification.name == UIKeyboardWillShowNotification)
        
        // baseContraint is your Auto Layout constraint that pins the
        // text view to the bottom of the superview.
        
        self.textChatBtm.constant = moveUp ? -keyboardHeight : 0
        
        let options = UIViewAnimationOptions(rawValue: curve << 16)
        UIView.animateWithDuration(duration, delay: 0, options: options,
                                   animations: {
                                    self.view.layoutIfNeeded()
            },
                                   completion: nil
        )
        
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
    When user disconnects from chat, present alert view informing other peer, return them to contact table view
    */
    func handleChatLoss(notification: NSNotification){
        let peerID = notification.object as! MCPeerID
        
        print("handling chat loss...")
        let alert = UIAlertController(title: "", message: "Connection to \(peerID.displayName) has been lost", preferredStyle: UIAlertControllerStyle.Alert)
        
        let doneAction : UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            self.dismissViewControllerAnimated(true, completion: { () -> Void in
                self.appDelegate.mpcManager.session.disconnect()
            })

        }

        alert.addAction(doneAction)
        NSOperationQueue.mainQueue().addOperationWithBlock( { () -> Void in
        self.presentViewController(alert, animated: true, completion: nil)
        })
    
    }

    
    /*
    Custom Implementation to send messages between peers
    When peers notified of message sent, append to array and update the sessions table chat
    If the user presses the X in the upper left hand corner to end the chat, close the connection and return to contacts table view
    */
    func handleMPCReceivedDataWithNotification(notification: NSNotification) {
        let receivedDataDictionary = notification.object as! Dictionary<String, AnyObject>
        
        let data = receivedDataDictionary["data"] as? NSData
        let fromPeer = receivedDataDictionary["fromPeer"] as? MCPeerID
        
        let dataDictionary = NSKeyedUnarchiver.unarchiveObjectWithData(data!) as! Dictionary<String, String>
        
        if let message = dataDictionary["message"]{
            if message != "end_chat" {
                var messageDictionary: [String: String] = ["sender": fromPeer!.displayName, "message": message]
                messagesArray.append(messageDictionary)
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    self.updateTableView()
                })
            }
            else{
                
                let alert = UIAlertController(title: "", message: "\(fromPeer!.displayName) ended the chat", preferredStyle: UIAlertControllerStyle.Alert)
                
                let doneAction : UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
                    self.appDelegate.mpcManager.session.disconnect()
                    self.dismissViewControllerAnimated(true, completion: nil)
                }
                
                alert.addAction(doneAction)
                NSOperationQueue.mainQueue().addOperationWithBlock( { () -> Void in
                    self.presentViewController(alert, animated: true, completion: nil)
                })
            }
        }
        
        
    }
    
    /*
    Collapse keyboard after message is sent. Send the data to peers in the session
    */
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        let messageDictionary: [String: String] = ["message": textField.text!]
        
        if appDelegate.mpcManager.sendData(dictionaryWithData: messageDictionary, toPeer: appDelegate.mpcManager.session.connectedPeers[0] as MCPeerID) {
            
            var dictionary: [String: String] = ["sender": "self", "message": textField.text!]
            messagesArray.append(dictionary)
            
            self.updateTableView()
            
        }
        else{
            print("Could not send data")
        }
        
        textField.text = ""
        return true
    }
    
    /*
    Reloads table data and readjusts UI to remain at top of table
    */
    func updateTableView() {
        tableChat.reloadData()
        
        if self.tableChat.contentSize.height > self.tableChat.frame.size.height {
            tableChat.scrollToRowAtIndexPath(NSIndexPath(forRow: messagesArray.count - 1, inSection: 0), atScrollPosition: UITableViewScrollPosition.Bottom,  animated: true)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messagesArray.count
    }
    
    /*
    Method to display received data. If message is sent by peer, display their name and message, otherwise display 
    own name and display message
    */
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("idCell")! as UITableViewCell
        
        let currentMessage = messagesArray[indexPath.row] as Dictionary<String, String>
        //print(currentMessage)
        
        if let sender = currentMessage["sender"] {
            var senderLabelText: String
            var senderColor: UIColor
            
            if sender == "self" {
                senderLabelText = "I said: "
                senderColor = UIColor.blueColor()
                
            }
            else {
                senderLabelText = sender + " said: "
                senderColor = UIColor.orangeColor()
            }
            
            cell.detailTextLabel?.text = senderLabelText
            cell.detailTextLabel?.textColor = senderColor
        }
        
        if let message = currentMessage["message"] {
            cell.textLabel?.text = message
        }
        return cell
    }
    
    /*
     End Chat method, called upon user pressing X on top toolbar of chatview controller
     Disconnects sessions between peers, returns them to contacts tab
    */
    @IBAction func endChat(sender: AnyObject) {
        let messageDictionary: [String: String] = ["message": "end_chat"]
        if appDelegate.mpcManager.sendData(dictionaryWithData: messageDictionary, toPeer: appDelegate.mpcManager.session.connectedPeers[0] as MCPeerID) {
            self.dismissViewControllerAnimated(true, completion: { () -> Void in
                self.appDelegate.mpcManager.session.disconnect()
            })
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
