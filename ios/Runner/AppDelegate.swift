import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backgroundTasks: [Int: UIBackgroundTaskIdentifier] = [:]
  private var nextBackgroundTaskId = 0

  /// Shared "open with" file channel; SceneDelegate pushes files through it.
  static var fileOpenChannel: FlutterMethodChannel?
  static var pendingOpenFilePath: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "OronBoxBackgroundTasks"
    ) else { return }
    let channel = FlutterMethodChannel(
      name: "oronbox/background_tasks",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "begin":
        self.nextBackgroundTaskId += 1
        let id = self.nextBackgroundTaskId
        let task = UIApplication.shared.beginBackgroundTask(
          withName: (call.arguments as? [String: Any])?["label"] as? String
        ) { [weak self] in
          self?.endBackgroundTask(id)
        }
        self.backgroundTasks[id] = task
        result(id)
      case "end":
        if let id = (call.arguments as? [String: Any])?["id"] as? Int {
          self.endBackgroundTask(id)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // MARK: Live Activity POC channel (local-only, no APNs)
    // Dart 侧通过 oronbox/live_activity 调用 startTest/endTest/enabled。
    // 这里刻意不接入业务逻辑，仅验证无签名 ad-hoc 包能否装载 Widget Extension。
    if #available(iOS 16.2, *) {
      let laChannel = FlutterMethodChannel(
        name: "oronbox/live_activity",
        binaryMessenger: registrar.messenger()
      )
      laChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "enabled":
          result(OronBoxLiveActivityBridge.areActivitiesEnabled())
        case "startTest":
          let args = call.arguments as? [String: Any]
          let id = OronBoxLiveActivityBridge.start(
            title: args?["title"] as? String ?? "OronBox POC",
            detail: args?["detail"] as? String ?? "灵动岛 POC 测试卡片",
            progress: args?["progress"] as? Double ?? 0.35
          )
          result(id)
        case "updateTest":
          guard let args = call.arguments as? [String: Any],
                let id = args["id"] as? String else { result(nil); return }
          OronBoxLiveActivityBridge.update(
            id: id,
            title: args["title"] as? String ?? "OronBox POC",
            detail: args["detail"] as? String ?? "更新",
            progress: args["progress"] as? Double ?? 0.75
          )
          result(nil)
        case "endTest":
          OronBoxLiveActivityBridge.end(id: call.arguments as? String)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    } else {
      let laChannel = FlutterMethodChannel(
        name: "oronbox/live_activity",
        binaryMessenger: registrar.messenger()
      )
      laChannel.setMethodCallHandler { call, result in
        if call.method == "enabled" { result(false) } else { result(nil) }
      }
    }

    let fileChannel = FlutterMethodChannel(
      name: "oronbox/file_open",
      binaryMessenger: registrar.messenger()
    )
    fileChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getInitialFile":
        result(Self.pendingOpenFilePath)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    AppDelegate.fileOpenChannel = fileChannel
  }

  private func endBackgroundTask(_ id: Int) {
    guard let task = backgroundTasks.removeValue(forKey: id),
          task != .invalid else { return }
    UIApplication.shared.endBackgroundTask(task)
  }
}
