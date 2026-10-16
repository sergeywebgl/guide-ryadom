package com.example.guide_ryadom

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.security.KeyStore
import java.util.UUID
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val alias = "guide_ryadom.oauth.v1"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "guide_ryadom/auth")
            .setMethodCallHandler { call, result ->
                if (call.method == "openBrowser") {
                    try {
                        val uri = Uri.parse(call.arguments as String)
                        val allowed = uri.scheme == "https" && uri.userInfo == null &&
                            uri.port == -1 && uri.fragment == null && (
                            (uri.host == "auth.openai.com" && uri.path == "/api/accounts/authorize") ||
                            (uri.host == "chatgpt.com" && uri.path == "/settings/usage"))
                        require(allowed)
                        startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
                        result.success(null)
                    } catch (_: Exception) { result.error("browser", "Browser unavailable", null) }
                } else if (call.method in listOf("hostId", "readVault", "writeVault")) {
                    worker.execute {
                        try {
                            val value: Any? = when (call.method) {
                                "hostId" -> hostId()
                                "readVault" -> readVault()
                                else -> { writeVault(call.arguments as String); null }
                            }
                            runOnUiThread { result.success(value) }
                        } catch (_: Exception) {
                            // Do not expose exception strings: they may contain sensitive inputs.
                            runOnUiThread { result.error("storage", "Secure storage unavailable", null) }
                        }
                    }
                } else { result.notImplemented() }
            }
    }

    private fun hostId(): String {
        val file = AtomicFile(File(noBackupFilesDir, "oauth-host-id"))
        if (file.baseFile.exists()) return String(file.readFully(), Charsets.UTF_8)
        val id = "urn:uuid:${UUID.randomUUID()}"
        atomicWrite(file, id.toByteArray(Charsets.UTF_8))
        return id
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256).build())
        return generator.generateKey()
    }

    private fun writeVault(value: String) {
        require(value.length <= 1_000_000)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        require(cipher.iv.size == 12)
        atomicWrite(AtomicFile(File(noBackupFilesDir, "oauth-vault")), cipher.iv + encrypted)
    }

    private fun readVault(): String? {
        val file = AtomicFile(File(noBackupFilesDir, "oauth-vault"))
        if (!file.baseFile.exists()) return null
        val bytes = file.readFully()
        require(bytes.size in 29..1_100_000)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        return String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8)
    }

    private fun atomicWrite(file: AtomicFile, bytes: ByteArray) {
        val stream = file.startWrite()
        try { stream.write(bytes); file.finishWrite(stream) }
        catch (error: Exception) { file.failWrite(stream); throw error }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }
}
