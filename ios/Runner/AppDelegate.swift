import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audio: GameAudio?
  private var bluetooth: BluetoothTransport?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocalBluetooth") {
      bluetooth = BluetoothTransport(messenger: registrar.messenger())
      audio = GameAudio(registrar: registrar)
    }
  }
}

// AVAudioPlayer 播放本地短音效；语音只使用系统已提供的中文 voice。
private final class GameAudio: NSObject, AVSpeechSynthesizerDelegate {
  private let channel: FlutterMethodChannel
  private let speech = AVSpeechSynthesizer()
  private var players: [String: AVAudioPlayer] = [:]
  private let prefs = UserDefaults.standard
  private var effectsOn: Bool
  private var speechOn: Bool
  private var muted: Bool
  private var active = true
  private var speechResults: [ObjectIdentifier: FlutterResult] = [:]
  private var tokens: [NSObjectProtocol] = []
  init(registrar: FlutterPluginRegistrar) {
    effectsOn = prefs.object(forKey: "ddz.effectsOn") as? Bool ?? true
    speechOn = prefs.bool(forKey: "ddz.speechOn")
    muted = prefs.bool(forKey: "ddz.muted")
    channel = FlutterMethodChannel(name: "cn.offline.doudizhu/audio", binaryMessenger: registrar.messenger())
    super.init()
    speech.delegate = self
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    tokens.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.suspend() })
    tokens.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.active = true })
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "initialize":
        for name in args["effects"] as? [String] ?? [] {
          let key = registrar.lookupKey(forAsset: "assets/audio/\(name).wav")
          let path = Bundle.main.path(forResource: key, ofType: nil) ??
            Bundle.main.privateFrameworksPath.map { "\($0)/App.framework/\(key)" }
          if let path = path, let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) {
            player.prepareToPlay(); self.players[name] = player
          }
        }
        // New tempo preference starts existing installations on Fast once.
        result(["effectsOn": self.effectsOn, "speechOn": self.speechOn, "muted": self.muted, "cardSize": self.prefs.object(forKey: "ddz.cardSize") as? Int ?? 1, "pace": self.prefs.object(forKey: "ddz.paceV2") as? Int ?? 0, "difficulty": self.prefs.string(forKey: "ddz.difficulty") ?? "普通"])
      case "settings":
        self.effectsOn = args["effectsOn"] as? Bool ?? true
        self.speechOn = args["speechOn"] as? Bool ?? false
        self.muted = args["muted"] as? Bool ?? false
        self.prefs.set(self.effectsOn, forKey: "ddz.effectsOn")
        self.prefs.set(self.speechOn, forKey: "ddz.speechOn")
        self.prefs.set(self.muted, forKey: "ddz.muted")
        self.prefs.set(args["cardSize"] as? Int ?? 1, forKey: "ddz.cardSize")
        self.prefs.set(args["pace"] as? Int ?? 0, forKey: "ddz.paceV2")
        self.prefs.set(args["difficulty"] as? String ?? "普通", forKey: "ddz.difficulty")
        if self.muted || !self.effectsOn { self.stopEffects() }
        if self.muted || !self.speechOn { self.stopSpeech() }
        result(nil)
      case "play":
        if self.active && self.effectsOn && !self.muted,
           let name = args["effect"] as? String, let player = self.players[name] {
          player.stop(); player.currentTime = 0
          player.volume = min(1, max(0, (args["volume"] as? NSNumber)?.floatValue ?? 0.4)); player.play()
        }
        result(nil)
      case "speak":
        if self.active && self.speechOn && !self.muted,
           let text = args["text"] as? String,
           let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "zh-CN" }) {
          self.stopSpeech()
          let utterance = AVSpeechUtterance(string: String(text.prefix(60)))
          utterance.voice = voice; utterance.volume = 0.65; utterance.rate = 0.52
          self.speechResults[ObjectIdentifier(utterance)] = result
          self.speech.speak(utterance)
        } else { result(nil) }
      case "stopEffects": self.stopEffects(); result(nil)
      case "stopSpeech": self.stopSpeech(); result(nil)
      case "suspend": self.suspend(); result(nil)
      case "resume": self.active = true; result(nil)
      case "dispose": self.suspend(); self.players.removeAll(); result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    speechResults.removeValue(forKey: ObjectIdentifier(utterance))?(nil)
  }
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    speechResults.removeValue(forKey: ObjectIdentifier(utterance))?(nil)
  }
  private func stopSpeech() {
    speech.stopSpeaking(at: .immediate)
    let pending = Array(speechResults.values)
    speechResults.removeAll()
    pending.forEach { $0(nil) }
  }
  private func stopEffects() { for player in players.values { player.stop(); player.currentTime = 0 } }
  private func suspend() { active = false; stopEffects(); stopSpeech() }
  deinit { tokens.forEach { NotificationCenter.default.removeObserver($0) } }
}
