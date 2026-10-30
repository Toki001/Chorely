import Flutter
import UIKit
import UserNotifications
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "chorely/local_store",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "prepareStoreDirectory", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      var directory = URL(fileURLWithPath: path).standardizedFileURL
      let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path + "/"
      guard directory.path.hasPrefix(home), directory.lastPathComponent == "chorely_private" else {
        result(FlutterError(code: "invalid_store_path", message: "Invalid local store directory", details: nil))
        return
      }
      do {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try FileManager.default.setAttributes(
          [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
          ofItemAtPath: directory.path
        )
        result(nil)
      } catch {
        result(FlutterError(code: "store_protection_failed", message: "Local store protection unavailable", details: nil))
      }
    }
  }
}
