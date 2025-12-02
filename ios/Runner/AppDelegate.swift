import Flutter
import UIKit
import GCDWebServer

@main
@objc class AppDelegate: FlutterAppDelegate {
  var nativeServerPlugin: NativeServerPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.smartpos/server",
                                      binaryMessenger: controller.binaryMessenger)
    nativeServerPlugin = NativeServerPlugin(channel: channel)
    channel.setMethodCallHandler(nativeServerPlugin?.handle)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

public class NativeServerPlugin: NSObject {
    private var server: GCDWebServer?
    private let channel: FlutterMethodChannel
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startServer":
            let args = call.arguments as? [String: Any]
            let port = args?["port"] as? UInt ?? 8080
            startServer(port: port, result: result)
        case "stopServer":
            stopServer(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startServer(port: UInt, result: @escaping FlutterResult) {
        if server != nil && server!.isRunning {
            result(false) // Already running
            return
        }
        
        server = GCDWebServer()
        
        // Handle all requests
        server?.addHandler(forMethod: "GET", pathRegex: ".*", request: GCDWebServerDataRequest.self, asyncProcessBlock: handleRequest)
        server?.addHandler(forMethod: "POST", pathRegex: ".*", request: GCDWebServerDataRequest.self, asyncProcessBlock: handleRequest)
        server?.addHandler(forMethod: "PUT", pathRegex: ".*", request: GCDWebServerDataRequest.self, asyncProcessBlock: handleRequest)
        server?.addHandler(forMethod: "DELETE", pathRegex: ".*", request: GCDWebServerDataRequest.self, asyncProcessBlock: handleRequest)
        server?.addHandler(forMethod: "OPTIONS", pathRegex: ".*", request: GCDWebServerDataRequest.self, asyncProcessBlock: handleRequest)
        
        do {
            try server?.start(options: [
                GCDWebServerOption_Port: port,
                GCDWebServerOption_BindToLocalhost: false,
                GCDWebServerOption_AutomaticallySuspendInBackground: false
            ])
            print("✅ iOS Server started on port \(port)")
            result(true)
        } catch {
            print("❌ Failed to start iOS server: \(error)")
            result(false)
        }
    }
    
    private func stopServer(result: @escaping FlutterResult) {
        if let server = server, server.isRunning {
            server.stop()
            self.server = nil
            print("✅ iOS Server stopped")
        }
        result(true)
    }
    
    private func handleRequest(request: GCDWebServerRequest, completion: @escaping GCDWebServerCompletionBlock) {
        guard let dataRequest = request as? GCDWebServerDataRequest else {
            completion(GCDWebServerDataResponse(statusCode: 500))
            return
        }
        
        // Prepare request data
        var headers: [String: String] = [:]
        for (key, value) in request.headers {
            if let keyStr = key as? String, let valStr = value as? String {
                headers[keyStr] = valStr
            }
        }
        
        var body: String? = nil
        if dataRequest.hasBody() {
            body = String(data: dataRequest.data, encoding: .utf8)
        }
        
        let requestData: [String: Any?] = [
            "method": request.method,
            "path": request.path,
            "headers": headers,
            "body": body
        ]
        
        // Call Flutter on Main Thread
        DispatchQueue.main.async {
            self.channel.invokeMethod("handleRequest", arguments: requestData) { flutterResult in
                if let responseData = flutterResult as? [String: Any] {
                    let statusCode = responseData["statusCode"] as? Int ?? 200
                    let body = responseData["body"] as? String ?? ""
                    let contentType = responseData["contentType"] as? String ?? "application/json"
                    let responseHeaders = responseData["headers"] as? [String: String] ?? [:]
                    
                    let response = GCDWebServerDataResponse(data: body.data(using: .utf8) ?? Data(), contentType: contentType)
                    response.statusCode = statusCode
                    
                    // Add headers (skip headers that GCDWebServer sets automatically)
                    let skipHeaders = Set(["content-length", "content-type", "server", "date"])
                    for (key, value) in responseHeaders {
                        if !skipHeaders.contains(key.lowercased()) {
                            response.setValue(value, forAdditionalHeader: key)
                        }
                    }
                    
                    // Add CORS headers
                    response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
                    response.setValue("GET, POST, PUT, DELETE, OPTIONS", forAdditionalHeader: "Access-Control-Allow-Methods")
                    response.setValue("Origin, Content-Type, X-API-Key", forAdditionalHeader: "Access-Control-Allow-Headers")
                    
                    completion(response)
                } else {
                    completion(GCDWebServerDataResponse(statusCode: 500))
                }
            }
        }
    }
}
