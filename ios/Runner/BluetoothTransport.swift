import Flutter
import MultipeerConnectivity
import UIKit

/// iOS 通过 MultipeerConnectivity 可靠消息直连；系统选择蓝牙或点对点 Wi-Fi。
final class BluetoothTransport: NSObject, FlutterStreamHandler, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    private let service = "ddz-local"
    private let identity: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var found: [String:MCPeerID] = [:]
    private var sink: FlutterEventSink?
    private var hosting = false
    private var epoch = 0
    private var connecting: Set<String> = []
    private let io = DispatchQueue(label: "ddz.send")
    init(messenger: FlutterBinaryMessenger) {
        let key = "ddz.peerId"
        let saved = UserDefaults.standard.string(forKey: key) ?? "牌友-\(UUID().uuidString.prefix(8))"
        UserDefaults.standard.set(saved, forKey: key)
        identity = MCPeerID(displayName: saved)
        super.init()
        makeSession()
        FlutterMethodChannel(name: "cn.offline.doudizhu/transport", binaryMessenger: messenger).setMethodCallHandler { [weak self] call, result in self?.call(call,result:result) }
        FlutterEventChannel(name: "cn.offline.doudizhu/events", binaryMessenger: messenger).setStreamHandler(self)
    }
    private func makeSession() { session = MCSession(peer: identity, securityIdentity:nil, encryptionPreference:.required); session.delegate = self }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink=events; return nil }
    func onCancel(withArguments arguments: Any?) -> FlutterError? { sink=nil; return nil }
    private func emit(_ event:[String:Any]) { DispatchQueue.main.async { [weak self] in self?.sink?(event) } }
    private func error(_ text:String) { emit(["type":"error","message":text]) }
    private func stop() { epoch += 1;advertiser?.stopAdvertisingPeer(); browser?.stopBrowsingForPeers();session.disconnect();found.removeAll();connecting.removeAll() }
    private func call(_ call:FlutterMethodCall,result:@escaping FlutterResult) {
        let args = call.arguments as? [String:Any] ?? [:]
        switch call.method {
        case "createRoom":
            stop();makeSession();hosting=true
            advertiser=MCNearbyServiceAdvertiser(peer:identity,discoveryInfo:["game":"斗地主"],serviceType:service);advertiser?.delegate=self;advertiser?.startAdvertisingPeer();result(nil)
        case "discover":
            stop();makeSession();hosting=false
            browser=MCNearbyServiceBrowser(peer:identity,serviceType:service);browser?.delegate=self;browser?.startBrowsingForPeers()
            let current=epoch
            DispatchQueue.main.asyncAfter(deadline:.now()+30) { [weak self] in guard let self=self,self.epoch==current else{return};self.browser?.stopBrowsingForPeers();self.emit(["type":"scanDone"]) };result(nil)
        case "join":
            guard let id=args["id"] as? String, let peer=found[id] else { result(FlutterError(code:"MISSING",message:"设备已离开，请重新搜索",details:nil));return }
            connecting.insert(id);browser?.invitePeer(peer,to:session,withContext:nil,timeout:30)
            let current=epoch
            DispatchQueue.main.asyncAfter(deadline:.now()+30) { [weak self] in guard let self=self,self.epoch==current,self.connecting.remove(id) != nil else{return};self.error("30 秒未连接，请靠近房主并重试") };result(nil)
        case "send":
            guard let message=args["message"] as? [String:Any],let payload=try? JSONSerialization.data(withJSONObject:message),payload.count>0,payload.count<=262144 else{result(FlutterError(code:"FRAME",message:"消息格式错误",details:nil));return}
            let id=args["peer"] as? String
            let targets=session.connectedPeers.filter { id == nil || $0.displayName == id }
            guard !targets.isEmpty else{result(FlutterError(code:"OFFLINE",message:"连接已断开",details:nil));return}
            var size=UInt32(payload.count).bigEndian;var frame=Data(bytes:&size,count:4);frame.append(payload)
            let active=session!
            io.async { [weak self] in do{try active.send(frame,toPeers:targets,with:.reliable)}catch{self?.error("发送失败，请检查连接") } };result(nil)
        case "dispose": stop();result(nil)
        default:result(FlutterMethodNotImplemented)
        }
    }
    func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didReceiveInvitationFromPeer peerID:MCPeerID,withContext context:Data?,invitationHandler:@escaping (Bool,MCSession?)->Void){
        DispatchQueue.main.async { let accept=self.hosting && self.session.connectedPeers.count+self.connecting.count<2;if accept{self.connecting.insert(peerID.displayName)};invitationHandler(accept,accept ? self.session:nil)
            if accept {let current=self.epoch;DispatchQueue.main.asyncAfter(deadline:.now()+30){if self.epoch==current{self.connecting.remove(peerID.displayName)}}}
        }
    }
    func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didNotStartAdvertisingPeer error:Error){self.error("无法创建房间，请允许本地网络权限并开启蓝牙/Wi-Fi：\(error.localizedDescription)")}
    func browser(_ browser:MCNearbyServiceBrowser,foundPeer peerID:MCPeerID,withDiscoveryInfo info:[String:String]?){DispatchQueue.main.async{self.found[peerID.displayName]=peerID;self.emit(["type":"found","id":peerID.displayName,"name":peerID.displayName])}}
    func browser(_ browser:MCNearbyServiceBrowser,lostPeer peerID:MCPeerID){DispatchQueue.main.async{self.found.removeValue(forKey:peerID.displayName)}}
    func browser(_ browser:MCNearbyServiceBrowser,didNotStartBrowsingForPeers error:Error){self.error("搜索失败，请允许本地网络权限：\(error.localizedDescription)")}
    func session(_ session:MCSession,peer peerID:MCPeerID,didChange state:MCSessionState){DispatchQueue.main.async{guard session === self.session else{return};if state == .connected{self.connecting.remove(peerID.displayName);self.emit(["type":"connected","peer":peerID.displayName])}else if state == .notConnected{self.connecting.remove(peerID.displayName);self.emit(["type":"left","peer":peerID.displayName])}}}
    func session(_ session:MCSession,didReceive data:Data,fromPeer peerID:MCPeerID){
        // MCSession 保留消息边界；仍校验同一长度前缀协议，不把消息当字节流拼接。
        guard data.count>=4 else{error("收到损坏消息");return}
        let n=data.prefix(4).reduce(UInt32(0)){($0<<8)|UInt32($1)}
        guard n>0,n<=262144,data.count==Int(n)+4,let object=try? JSONSerialization.jsonObject(with:data.dropFirst(4)),let message=object as? [String:Any] else{error("收到非法消息");return}
        emit(["type":"message","peer":peerID.displayName,"message":message])
    }
    func session(_ session:MCSession,didReceive stream:InputStream,withName streamName:String,fromPeer peerID:MCPeerID){}
    func session(_ session:MCSession,didStartReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,with progress:Progress){}
    func session(_ session:MCSession,didFinishReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,at localURL:URL?,withError error:Error?){}
}
