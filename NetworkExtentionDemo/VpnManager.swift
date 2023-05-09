//
//  VpnManager.swift
//  NetworkExtentionDemo
//
//  Created by 黄龙 on 2023/5/9.
//

import UIKit
import NetworkExtension

public enum ManagerError: Error {
    case invalidProvider
    case vpnStartFail
}

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
    
    
    open func switchVPN(_ completion: ((NETunnelProviderManager?, Error?) -> Void)? = nil) {
        loadProviderManager { [unowned self] (manager) in
            if let manager = manager {
                self.updateVPNStatus(manager)
            }
            let current = self.vpnStatus
            guard current != .connecting && current != .disconnecting else {
                return
            } //只要不是off都关闭会怎么样
            if current == .off {
                self.startVPN(nil) { (manager, error) -> Void in
                    completion?(manager, error)
                }
            }else {
                self.stopVPN()
                completion?(nil, nil)
            }
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
    
    public func startVPN(_ options: [String : NSObject]?, complete: ((NETunnelProviderManager?, Error?) -> Void)? = nil) {
        // Load provider
        loadAndCreateProviderManager { (manager, error) -> Void in
            if let error = error {
                complete?(nil, error)
            }else{
                guard let manager = manager else {
                    complete?(nil, ManagerError.invalidProvider)
                    return
                }
                
                if manager.connection.status == .disconnected || manager.connection.status == .invalid {
                    do {
//要拦截流量，需要主App启动Network Extension进程，
//即通过调用NETunnelProviderManager对象tunnel的tunnel.connection.startVPNTunnel()方法。开启VPN通道
                        try manager.connection.startVPNTunnel(options: options)
                        self.addVPNStatusObserver()
                        complete?(manager, nil)
                    }catch {
                        complete?(nil, error)
                    }
                }else{
                    self.addVPNStatusObserver()
                    complete?(manager, nil)
                }
            }
        }
    }
    
    public func stopVPN() {
        // Stop provider
        loadProviderManager { (manager) -> Void in
            guard let manager = manager else {
                return
            }
//stopVPNTunnel关闭VPN通道
            manager.connection.stopVPNTunnel()
        }
    }
    
    fileprivate func loadAndCreateProviderManager(_ complete: @escaping (NETunnelProviderManager?, Error?) -> Void ) {
        NETunnelProviderManager.loadAllFromPreferences { [unowned self] (managers, error) -> Void in
// NETunnelProviderManager.loadAllFromPreferences,读取manager配置，
// saveToPreferences如果调用多次，会出现VPN 1 VPN 2等多个描述文件，故苹果要求，在创建前应读取当前的managers。
// 而loadAllFromPreferences获取，第一次肯定是nil，
            
            if let managers = managers {
                let manager: NETunnelProviderManager
                if managers.count > 0 {
                    manager = managers[0]
                }else{
                    manager = self.createProviderManager()
                }
                manager.isEnabled = true
                manager.localizedDescription = "我爱一条柴"
                // 任意值,显示在设置VPN中的vpn名称，可以写成如： "我爱一条柴"
                manager.protocolConfiguration?.serverAddress = "127.0.0.1"
                // 任意值,显示在设置-VPN-Detial中的“服务器”值，可以写成如："上山打老虎"
                manager.protocolConfiguration?.excludeLocalNetworks = true

//-----按需连接(按需开启代理)配置，在vpn关闭的情况，如果监测到外网请求自动开启vpn；
//                manager.isOnDemandEnabled = true //默认开关状态为false
// isOnDemandEnabled按需启动，Toggles VPN On Demand. 按需启动开关
//                let quickStartRule = NEOnDemandRuleEvaluateConnection()
////// NEEvaluateConnectionRule将网络连接的属性与操作相关联
////                let autoDomains = ["google.com","youtube.com","wikipedia.org","facebook.com","twitter.com","instagram.com","snapchat.com","voachinese.com","dw.com","bbc.com","rfi.fr","cnn.com","news.sky.com","cw.com","apnews.com","aljazeera.net","whatsapp.com","whatsapp.net"]
////                "aljazeera.net" 半岛电视台
//                quickStartRule.connectionRules = [NEEvaluateConnectionRule(matchDomains:["google.com","youtube.com"] , andAction: NEEvaluateConnectionRuleAction.connectIfNeeded)]
//////              按需连接,如果开关开启，则在打开google.com时，会自动开启VPN(VPN关闭的情况下)
//                manager.onDemandRules = [quickStartRule]
                
// saveToPreferences将manager保存至系统中, 如果saveToPreferences方法调用多次，会出现VPN 1 VPN 2等多个描述文件
                manager.saveToPreferences(completionHandler: { (error) -> Void in
                    if let error = error {
                        complete(nil, error)
                    }else{
                        manager.loadFromPreferences(completionHandler: { (error) -> Void in
                            if let error = error {
                                complete(nil, error)
                            }else{
                                complete(manager, nil)
                            }
                        })
                    }
                })
            }else{
                complete(nil, error)
            }
        }
    }
    
    fileprivate func createProviderManager() -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        manager.protocolConfiguration = NETunnelProviderProtocol()
        return manager
    }
    
}
