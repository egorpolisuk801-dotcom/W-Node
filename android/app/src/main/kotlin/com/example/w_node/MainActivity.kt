package com.example.w_node

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "w12/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "tailscaleInstalled") {
                    val installed = try {
                        packageManager.getPackageInfo("com.tailscale.ipn", 0)
                        true
                    } catch (_: PackageManager.NameNotFoundException) {
                        false
                    }
                    result.success(installed)
                } else {
                    result.notImplemented()
                }
            }
    }
}
