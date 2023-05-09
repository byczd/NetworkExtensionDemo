//
//  VpnManager.swift
//  NetworkExtentionDemo
//
//  Created by 黄龙 on 2023/5/9.
//

import UIKit
import NetworkExtension


public enum VPNStatus {
    case off
    case connecting
    case on
    case disconnecting
}

public let kProxyServiceVPNStatusNotification = "kProxyServiceVPNStatusNotification"


class VpnManager{
    var observerAdded: Bool = false
    
    public static let sharedManager = VpnManager()
    
    open fileprivate(set) var vpnStatus = VPNStatus.off {
        didSet {
            NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServiceVPNStatusNotification), object: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    fileprivate init() {
        loadProviderManager { (manager) -> Void in
            if let manager = manager {
                self.updateVPNStatus(manager)
            }
        }
        addVPNStatusObserver()
    }
    
    func addVPNStatusObserver() {
        guard !observerAdded else{
            return
        }
        
        loadProviderManager { [unowned self] (manager) -> Void in
            if let manager = manager {
                self.observerAdded = true
//  可以通过NEVPNStatusDidChangeNotification通知来获取当前VPN的状态。
                NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: manager.connection, queue: OperationQueue.main, using: { [unowned self] (notification) -> Void in
                    print("NEVPNStatusDidChange[\(manager.connection.status.rawValue)]")
                    //invalid=0,Disconnected=1,connecting=2,connected=3,disconnecting=5
                    self.updateVPNStatus(manager)
                })
            }
        }
    }
    
    func updateVPNStatus(_ manager: NEVPNManager) {
        switch manager.connection.status {
        case .connected:
            self.vpnStatus = .on
        case .connecting, .reasserting:
            self.vpnStatus = .connecting
        case .disconnecting:
            self.vpnStatus = .disconnecting
        case .disconnected, .invalid:
            self.vpnStatus = .off
        default:
            self.vpnStatus = .off
        }
    }
    
    
}

extension VpnManager {
    public func loadProviderManager(_ complete: @escaping (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) -> Void in
// managers为NSArray<NETunnelProviderManager *>,  NETunnelProviderManager为NEVPNManager的子类
            if let managers = managers {//最终VPN能否开启成功
                if managers.count > 0 {
                    let manager = managers[0]
                    complete(manager)
                    return
                }
            }
            complete(nil)
        }
    }
    
}
