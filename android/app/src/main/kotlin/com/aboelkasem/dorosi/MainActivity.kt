package com.aboelkasem.dorosi

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dorosi/contacts").setMethodCallHandler { call, result ->
            if (call.method != "pickPhone") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            pending?.success(null)
            pending = result
            // The system picker hands back the chosen number without asking for the contacts permission.
            val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
            try {
                startActivityForResult(intent, PICK_PHONE)
            } catch (e: ActivityNotFoundException) {
                pending = null
                result.error("no_contacts_app", e.message, null)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_PHONE) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.query(
                uri,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ),
                null,
                null,
                null,
            )?.use { c ->
                if (c.moveToFirst()) {
                    result.success(mapOf("number" to (c.getString(0) ?: ""), "name" to (c.getString(1) ?: "")))
                    return
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("read_failed", e.message, null)
        }
    }

    companion object {
        private const val PICK_PHONE = 4207
    }
}
