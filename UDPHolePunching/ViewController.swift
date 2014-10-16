//
//  ViewController.swift
//  UDPHolePunching
//
//  Created by Yunus Eren Guzel on 08/10/14.
//  Copyright (c) 2014 Yunus Eren Guzel. All rights reserved.
//

import UIKit
enum AppStatus {
    case None
    case Unregistered
    case Registering
    case Registered
    case RetrievingOthers
    case WillPunch
    case Punching
    case WillNotify
    case Notifying
    case ReadyAndWaitingForCall
    case WillCall
    
}
enum ConnectionCodes {
    case Register, GetOthers, ReadyAndNotify,Call,Alert
    func string() -> String {
        switch self {
        case .Register:
            return "R"
        case .GetOthers:
            return "G"
        case .ReadyAndNotify:
            return "N"
        case .Call:
            return "C"
        case .Alert:
            return "A"
        }
    }
}

class ViewController: UIViewController, GCDAsyncUdpSocketDelegate {
    let host:String = "54.69.234.65" 
//    let host:String = "192.168.1.106"
    let port:UInt16 = 3366
    var socket:GCDAsyncUdpSocket!
    var button:UIButton!
    var peerIp:String!
    var peerPort:UInt16!
    var status:AppStatus = AppStatus.None{
        didSet {
            var color:UIColor = UIColor.blackColor()
//            var action:Selector!
            var title:String!
            switch(status) {
            case .Unregistered:
                title = "Register"
            case .Registered:
                color = UIColor.greenColor();
                title = "Get Others"
            case .Registering:
                color = UIColor.yellowColor();
            case .RetrievingOthers:
                color = UIColor.orangeColor();
            case .WillPunch:
                color = UIColor.redColor()
                title = "Punch!"
            case .WillCall:
                title = "Call!"
            default:
                color = UIColor.blackColor();
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.button.backgroundColor = color;
                if(title != nil) {
                    self.button.setTitle(title, forState: UIControlState.Normal)
                }
                self.textField.hidden = self.status != AppStatus.Unregistered
            });
        }
    }
    var activityIndicator:UIActivityIndicatorView!
    var textField:UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator = UIActivityIndicatorView(frame: CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height))
        socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: dispatch_get_main_queue());
        var error:NSError?;
        if !socket.bindToPort(0, error: &error) {
           NSLog("cant bind to port %@", error!)
        }
        if !socket.beginReceiving(&error) {
           NSLog("cant receive from port %@", error!)
        }
        button = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
        button.frame = CGRectMake(0.0, 200.0, self.view.frame.size.width, 50)
        button.addTarget(self, action: "buttonPressed", forControlEvents: UIControlEvents.TouchUpInside)
        self.view.addSubview(button)
        
        self.textField = UITextField(frame: CGRectMake(0.0, 120.0, self.view.frame.size.width, 50.0));
        self.textField.borderStyle = UITextBorderStyle.Line;
        self.view.addSubview(self.textField)
        
        status = AppStatus.Unregistered
    }
    func buttonPressed () {
        switch self.status {
        case .Unregistered:
            register();
        case .Registered:
            getOthers()
        case .WillCall:
            call();
        default:
            1==1
        }
    }
    func startActivityIndicator() {
        self.view.addSubview(self.activityIndicator)
        self.activityIndicator.startAnimating()
    }
    
    func stopActivityIndicator() {
        self.activityIndicator.removeFromSuperview()
        self.activityIndicator.stopAnimating()
    }
    
    func udpSocket(sock: GCDAsyncUdpSocket!, didNotSendDataWithTag tag: Int, dueToError error: NSError!) {
        NSLog("data sent error %@", error);
    }
    
    func udpSocket(sock: GCDAsyncUdpSocket!, didReceiveData data: NSData!, fromAddress address: NSData!, withFilterContext filterContext: AnyObject!) {
        var string = NSString(data: data, encoding: NSUTF8StringEncoding)
        var code = string.substringToIndex(1)
        var message = string.substringFromIndex(1)
        NSLog("\ncode: %@ \nmessage: %@", code,message);
        if code == ConnectionCodes.Register.string() {
            self.status = AppStatus.Registered;
            NSLog("registered!")
        }
        else if code == ConnectionCodes.GetOthers.string() {
            var error:NSError?
            var json:AnyObject! = NSJSONSerialization.JSONObjectWithData(message.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!, options: NSJSONReadingOptions.AllowFragments, error: &error)
            NSLog("ready and will call");
            var array:NSArray = json as NSArray
            if(array.count > 0) {
                var element:NSString = array.objectAtIndex(0) as String
                self.peerIp = element.componentsSeparatedByString(":")[0] as String
                var portString:NSString = element.componentsSeparatedByString(":")[1] as String
                self.peerPort = NSNumber(int: portString.intValue).unsignedShortValue
                self.status = AppStatus.WillCall;
            }
            else {
                self.status = AppStatus.Registered;
            }
        }
        else if code == ConnectionCodes.ReadyAndNotify.string() {
            self.status = AppStatus.ReadyAndWaitingForCall
            NSLog("Waiting for a call")
        }
        else if code == ConnectionCodes.Call.string() {
            self.status = AppStatus.WillCall
            var error:NSError?
            var json:AnyObject! = NSJSONSerialization.JSONObjectWithData(message.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!, options: NSJSONReadingOptions.AllowFragments, error: &error)
            NSLog("ready and will call");
            if(json != nil) {
                var array:NSArray = json as NSArray
                if(array.count > 0) {
                    var element:NSString = array.objectAtIndex(0) as String
                    self.peerIp = element.componentsSeparatedByString(":")[0] as String
                    var portString:NSString = element.componentsSeparatedByString(":")[1] as String
                    self.peerPort = NSNumber(int: portString.intValue).unsignedShortValue
                }
            }
        }
        else if code == ConnectionCodes.Alert.string() {
            self.status = AppStatus.WillCall
            var host:NSString?
            var port:UInt16 = 0
            GCDAsyncUdpSocket.getHost(&host, port: &port, fromAddress: address)
            UIAlertView(title: host, message: message, delegate: self, cancelButtonTitle: "OK").show()
        }

    }
    func call() {
        var message = "Hello Buddy!"
        var code = ConnectionCodes.Alert.string()
        var responseText = code + message;
        var data:NSData! = responseText.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false);
        self.socket.sendData(data, toHost: self.peerIp, port: self.peerPort, withTimeout: -1, tag: 1);
    }
    func register(){
//        if self.textField.text.utf16Count > 0 {
//            return;
//        }
        var timeout:NSTimeInterval = 3
        var queue : dispatch_queue_t = dispatch_queue_create("com.UDPHolePunching", nil)
        dispatch_async(queue, {
            var startTime:NSDate!
            while true {
                if(self.status == AppStatus.Unregistered) {
                    startTime = NSDate();
                    self.sendText(ConnectionCodes.Register.string(), message: self.textField.text);
                    self.status = AppStatus.Registering
                    NSLog("registration started")
                }
                else if(self.status == AppStatus.Registering) {
                    if NSDate().timeIntervalSinceDate(startTime) > timeout {
                        self.status = AppStatus.Unregistered
                        NSLog("registration timeout")
                    }
                }
                else {
                    NSLog("registered!");
                    break;
                }
            }
        });
    }
    
    func getOthers() {
//        var timeout:NSTimeInterval = 3
//        var queue : dispatch_queue_t = dispatch_queue_create("com.UDPHolePunching",nil)
//        dispatch_async(queue, { () -> Void in
//            var startTime:NSDate!
//            while true {
//                if self.status == AppStatus.Registered {
//                    startTime = NSDate();
                    self.sendText(ConnectionCodes.GetOthers.string(), message: nil)
                    self.status = AppStatus.RetrievingOthers
//                    NSLog("Retrieving others")
//                }
//                else if self.status == AppStatus.RetrievingOthers {
//                    if NSDate().timeIntervalSinceDate(startTime) > timeout {
//                        self.status = AppStatus.Registered
//                        NSLog("retrieving others timoeut")
//                    }
//                }
//                else {
//                    break;
//                }
//            }
//        });
    }
    
    func punch(){
        var timeout:NSTimeInterval = 3
        var queue : dispatch_queue_t = dispatch_queue_create("com.UDPHolePunching",nil)
        dispatch_async(queue, { () -> Void in
            var startTime:NSDate!
            var count = 3;
            while true {
                if self.status == AppStatus.WillPunch {
                    startTime = NSDate();
                    self.socket.sendData("AI punch you".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false), toHost: self.peerIp, port: self.peerPort, withTimeout: -1, tag: 1)
                    self.status = AppStatus.Punching
                    NSLog("punching")
                }
                else if(self.status == AppStatus.Punching) {
                    if NSDate().timeIntervalSinceDate(startTime) > timeout {
                        if count > 0 {
                            count--;
                            self.status = AppStatus.WillPunch;
                        }
                        else {
                            self.status = AppStatus.WillNotify;
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.notifyAndWaitForCall();
                            });
                            break;
                        }
                    }
                }
                else {
                    break;
                }
            }
        });

    }
    
    func notifyAndWaitForCall(){
        var timeout:NSTimeInterval = 3
        var queue : dispatch_queue_t = dispatch_queue_create("com.UDPHolePunching",nil)
        dispatch_async(queue, { () -> Void in
            var startTime:NSDate!
            while true {
                if self.status == AppStatus.WillNotify {
                    startTime = NSDate();
                    var message = self.peerIp + ":" + String(self.peerPort)
                    self.sendText(ConnectionCodes.ReadyAndNotify.string(), message: message)
                    self.status = AppStatus.Notifying
                    NSLog("will notify")
                }
                else if self.status == AppStatus.Notifying {
                    if NSDate().timeIntervalSinceDate(startTime) > timeout {
                        self.status = AppStatus.WillNotify
                        NSLog("notifying timoeut")
                    }
                }
                else if self.status == AppStatus.ReadyAndWaitingForCall {
                    break;
                }
            }
        });
        
    }

    
    func sendText(code:String,message:String!) {
        var responseText = message != nil ? code + message : code;
        var data:NSData! = responseText.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false);
        socket.sendData(data, toHost: self.host, port: self.port, withTimeout: -1, tag: 1);
    }
    func udpSocket(sock: GCDAsyncUdpSocket!, didSendDataWithTag tag: Int) {
        NSLog("data sent!");
//        if(self.status == AppStatus.Punching) {
//            self.status = AppStatus.WillNotify
//        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    


}

