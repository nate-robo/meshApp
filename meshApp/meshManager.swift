//
//  meshManager.swift
//  meshApp
//
//  Created by Nathan on 3/3/16.
//  Copyright © 2016 Nathan. All rights reserved.
//

import MultipeerConnectivity
import UIKit


/*
 Custom protocol class used to handle the Multipeer connectivity functionality (Instead of using MCProtocolDelegate
 */
protocol MPCManagerDelegate {
    func foundPeer()
    
    func lostPeer()
    
    func invitationReceived(fromPeer: String)
    
    func connectedWithPeer(peerID: MCPeerID)
    
}

//Handles the Multipeer connectivity framework implementation and adherence to neccesary protocols
//Responsible for all the networking that enables the peer to peer connections
class MPCManager: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    var delegate: MPCManagerDelegate?
    var peer: MCPeerID!
    var session: MCSession!
    
    var browser: MCNearbyServiceBrowser!
    var advertiser: MCNearbyServiceAdvertiser!
    var invitationHandler: ((Bool, MCSession)->Void)!
    
    var foundPeers = [MCPeerID]()
    
    
    override init() {
        super.init()
        
        
        // Duplicate table entry work around - Apple identified bug where MPC peerID intialization in viewDidLoad method causes duplicate entries of the same device. Serialize and store peerID's to prevent duplicate PeerID's for same device
        // PeerID is the base object to represent devices in the MPC network / framework
        if (NSUserDefaults.standardUserDefaults().dataForKey("PeerID") == nil) {
            print("peer ID is nil")
            self.peer = MCPeerID(displayName: UIDevice.currentDevice().name)
            NSUserDefaults.standardUserDefaults().setObject(NSKeyedArchiver.archivedDataWithRootObject(peer), forKey:"PeerID")
        }
        else {
            self.peer = NSKeyedUnarchiver.unarchiveObjectWithData((NSUserDefaults.standardUserDefaults().dataForKey("PeerID"))!) as! MCPeerID
            print("peer ID is NOT nil")
        }
        
        //peer = MCPeerID(displayName: UIDevice.currentDevice().name)
        
        //Device can create a session (connection) with other devices
        session = MCSession(peer: peer)
        session.delegate = self
        
        //Device can browse for nearby devices
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: "robo-mesh")
        browser.delegate = self
        
        //Device can be discovered by nearby devices
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: "robo-mesh")
        advertiser.delegate = self
        
    }
    
    
    /*
    sendData MCSesssion Delegate Protocol conformity
    Sends the sieralized data <PeerID.displayName, message>
    Print error if sending is unsuccesful
    
    returns true / false if the data was succesfully sent or not
    */
    func sendData(dictionaryWithData dictionary: Dictionary<String, String>, toPeer targetPeer: MCPeerID) -> Bool {
        let dataToSend = NSKeyedArchiver.archivedDataWithRootObject(dictionary)
        let peersArray = NSArray(object: targetPeer)
        
        do {
            try session.sendData(dataToSend, toPeers: peersArray as! [MCPeerID], withMode: MCSessionSendDataMode.Reliable)
        } catch let error as NSError {
            print(error.localizedDescription)
            return false
        }
        
        return true
        
    }
    
    
    /*
    MCSessionDelegate Protocol conformity
    Once data is received from a sender, post a notification to indicate need to display information in chat
    */
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        let dictionary: [String: AnyObject] = ["data": data, "fromPeer": peerID]
        NSNotificationCenter.defaultCenter().postNotificationName("receivedMPCDataNotification", object: dictionary) //custom way to handle receiving data, post notifcation, all peers listen for it and update accordingly
    }
    
    
    /*
    MCSessionDelegate Protocol conformity
    Try to connect with another peer and create a session
        - Connecting
        - Connected, delegate to superclass
        - Didn't connect, addtionally handles chat connection losses
    */
    func session(session: MCSession, peer peerID:MCPeerID, didChangeState state: MCSessionState) {
        switch state {
        case MCSessionState.Connected:
            print("Connected to session: \(session)")
            delegate?.connectedWithPeer(peerID)
            
        case MCSessionState.Connecting:
            print("Connecting to session: \(session)")
            
        case MCSessionState.NotConnected:
            print("Did not connect to session: \(session)")
            NSNotificationCenter.defaultCenter().postNotificationName("chatLossNotification", object: peerID)
        }
        
    }
    
    /*
    MCNearbyAdvertiserDelegate protocol conformity
    Handles when another peer invites to join a session
    */
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: (Bool, MCSession) -> Void) {
        self.invitationHandler = invitationHandler
        delegate?.invitationReceived(peerID.displayName)
    }
    
    

    
    //MCNearbyAdvertiserDelegate protocol conformity - error checking advertising properly
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        print(error.localizedDescription)
    }
    
    
    //MCNearbyBrowserDelegate protocol conformity 
    //When we find a peer append to the array of peers within vicinity of eacother
    //Delegate to superclass, update UI
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        foundPeers.append(peerID)
        
        delegate?.foundPeer()
    }

    
    //MCNearbyBrowserDelegate protocol conformity
    //lost a peer, search through foundPeers array, remove them from array, update UI
    //Delegate to superclass
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        for(index, aPeer) in foundPeers.enumerate() {
            if aPeer == peerID {
                foundPeers.removeAtIndex(index)
                break
            }
        }
        
        delegate?.lostPeer()
    }
    
    //Error Browsing
    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        print(error.localizedDescription)
    }
    
    //Auxilary functions - conform to protocol, not used
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) { }
    
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) { }
    
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    
    

}
