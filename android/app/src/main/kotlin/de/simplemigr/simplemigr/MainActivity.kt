package de.simplemigr.simplemigr

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Wartet auf die Rückkehr aus der Einstellung „Unbekannte Apps installieren“.
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "simplemigr/install")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(canInstall())
                    "requestPermission" -> {
                        if (canInstall()) {
                            result.success(true)
                        } else {
                            pendingPermission?.success(false)
                            pendingPermission = result
                            startActivityForResult(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                ),
                                REQUEST_INSTALL_PERMISSION,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_INSTALL_PERMISSION) {
            pendingPermission?.success(canInstall())
            pendingPermission = null
        }
    }

    // Vor Android 8 gilt die globale Einstellung „Unbekannte Quellen“, der Installer fragt selbst.
    private fun canInstall() =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    private companion object {
        const val REQUEST_INSTALL_PERMISSION = 4711
    }
}
