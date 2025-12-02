package com.smartpos.smart_pos

import android.os.Handler
import android.os.Looper
import fi.iki.elonen.NanoHTTPD
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class NativeServerPlugin(private val channel: MethodChannel) : MethodChannel.MethodCallHandler {
    private var server: SimpleWebServer? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startServer" -> {
                val port = call.argument<Int>("port") ?: 8080
                startServer(port, result)
            }
            "stopServer" -> {
                stopServer(result)
            }
            else -> result.notImplemented()
        }
    }

    private fun startServer(port: Int, result: MethodChannel.Result) {
        if (server != null) {
            result.success(false) // Already running
            return
        }

        try {
            server = SimpleWebServer(port, channel, handler)
            server?.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false)
            result.success(true)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("SERVER_START_FAILED", e.message, null)
        }
    }

    private fun stopServer(result: MethodChannel.Result) {
        if (server != null) {
            server?.stop()
            server = null
        }
        result.success(true)
    }

    private class SimpleWebServer(
        port: Int,
        private val channel: MethodChannel,
        private val handler: Handler
    ) : NanoHTTPD("0.0.0.0", port) {

        override fun serve(session: IHTTPSession): Response {
            val latch = CountDownLatch(1)
            var responseData: Map<String, Any?>? = null
            
            // Read body if present
            val map = HashMap<String, String>()
            try {
                session.parseBody(map)
            } catch (e: Exception) {
                // Ignore
            }
            
            // Prepare request data for Flutter
            val requestData = hashMapOf(
                "method" to session.method.name,
                "path" to session.uri,
                "headers" to session.headers,
                "body" to map["postData"] // NanoHTTPD puts body in "postData" key
            )

            // Call Flutter on Main Thread
            handler.post {
                channel.invokeMethod("handleRequest", requestData, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (result is Map<*, *>) {
                            @Suppress("UNCHECKED_CAST")
                            responseData = result as Map<String, Any?>
                        }
                        latch.countDown()
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        latch.countDown()
                    }

                    override fun notImplemented() {
                        latch.countDown()
                    }
                })
            }

            // Wait for Flutter response (timeout 10s)
            try {
                latch.await(10, TimeUnit.SECONDS)
            } catch (e: InterruptedException) {
                e.printStackTrace()
            }

            if (responseData == null) {
                return newFixedLengthResponse(
                    Response.Status.INTERNAL_ERROR,
                    MIME_PLAINTEXT,
                    "Internal Server Error: No response from app"
                )
            }

            val statusCode = (responseData!!["statusCode"] as? Int) ?: 200
            val body = (responseData!!["body"] as? String) ?: ""
            val contentType = (responseData!!["contentType"] as? String) ?: "application/json"
            
            val status = Response.Status.lookup(statusCode) ?: Response.Status.OK
            
            val response = newFixedLengthResponse(status, contentType, body)
            
            // Add headers (skip headers that NanoHTTPD sets automatically)
            val headers = responseData!!["headers"] as? Map<*, *>
            val skipHeaders = setOf("content-length", "content-type", "server", "date")
            headers?.forEach { (k, v) ->
                if (k is String && v is String) {
                    if (!skipHeaders.contains(k.lowercase())) {
                        response.addHeader(k, v)
                    }
                }
            }
            
            // Add CORS headers by default if not present
            response.addHeader("Access-Control-Allow-Origin", "*")
            response.addHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
            response.addHeader("Access-Control-Allow-Headers", "Origin, Content-Type, X-API-Key")

            return response
        }
    }
}
