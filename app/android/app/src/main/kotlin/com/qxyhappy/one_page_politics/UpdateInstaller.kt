package com.qxyhappy.one_page_politics

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * 应用内更新所需的 Android 能力：读取当前版本、校验下载的 APK、
 * 调起系统安装器，以及安装权限设置。
 *
 * 校验在后台线程完成；结果统一回传到主线程。签名比对使用已安装应用
 * 与下载包双方的当前签名证书，签名不一致时拒绝覆盖安装。
 */
class UpdateInstaller(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val appContext = activity.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "update-installer")
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installedApp" -> result.success(installedApp())
            "verifyApk" -> verifyApk(call, result)
            "installApk" -> result.success(installApk(call.argument<String>("path")))
            "openInstallSettings" -> result.success(openInstallSettings())
            "openUrl" -> result.success(openUrl(call.argument<String>("url")))
            "keepScreenOn" -> {
                setKeepScreenOn(call.argument<Boolean>("enabled") == true)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun installedApp(): Map<String, Any?> {
        val info = appContext.packageManager.getPackageInfo(appContext.packageName, 0)
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf(
            "versionCode" to versionCode,
            "versionName" to (info.versionName ?: ""),
            "packageName" to appContext.packageName,
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun verifyApk(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val expectedSha256 = call.argument<String>("sha256")
        val expectedVersionCode =
            (call.argument<Any>("versionCode") as? Number)?.toLong()
        if (path.isNullOrEmpty() || expectedSha256.isNullOrEmpty() || expectedVersionCode == null) {
            result.success(mapOf("ok" to false, "message" to "校验参数不完整"))
            return
        }
        worker.execute {
            val outcome = try {
                verify(path, expectedSha256, expectedVersionCode)
            } catch (error: Exception) {
                failed("校验失败：${error.message}")
            }
            mainHandler.post { result.success(outcome) }
        }
    }

    private fun verify(
        path: String,
        expectedSha256: String,
        expectedVersionCode: Long,
    ): Map<String, Any?> {
        val file = File(path)
        if (!file.isFile || file.length() == 0L) return failed("安装包不存在")
        if (!sha256(file).equals(expectedSha256, ignoreCase = true)) {
            return failed("安装包 SHA-256 与更新清单不一致")
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
        val archive = appContext.packageManager.getPackageArchiveInfo(file.absolutePath, flags)
            ?: return failed("无法读取安装包")
        if (archive.packageName != appContext.packageName) {
            return failed("安装包包名不一致")
        }
        val archiveVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            archive.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            archive.versionCode.toLong()
        }
        if (archiveVersionCode != expectedVersionCode) {
            return failed("安装包版本与更新清单不一致")
        }

        val installed = appContext.packageManager.getPackageInfo(appContext.packageName, flags)
        val archiveSigners = signerHashes(archive)
        val installedSigners = signerHashes(installed)
        if (archiveSigners.isEmpty() || archiveSigners != installedSigners) {
            return failed("安装包签名与已安装版本不一致，无法覆盖安装")
        }
        return mapOf("ok" to true)
    }

    private fun signerHashes(info: PackageInfo): Set<String> {
        val signatures: Array<Signature> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners ?: return emptySet()
        } else {
            @Suppress("DEPRECATION")
            info.signatures ?: return emptySet()
        }
        return signatures.map { signature -> sha256(signature.toByteArray()) }.toSet()
    }

    private fun installApk(path: String?): Map<String, Any?> {
        if (path.isNullOrEmpty()) return failed("安装包路径为空")
        val file = File(path)
        if (!file.isFile) return failed("安装包不存在")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !appContext.packageManager.canRequestPackageInstalls()
        ) {
            return mapOf(
                "status" to "permission_required",
                "message" to "需要在系统设置中允许本应用安装应用",
            )
        }
        return try {
            val uri = FileProvider.getUriForFile(
                appContext,
                "${appContext.packageName}.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            mapOf("status" to "started", "message" to "")
        } catch (error: Exception) {
            mapOf(
                "status" to "failed",
                "message" to "无法调起系统安装器：${error.message}",
            )
        }
    }

    private fun openInstallSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            activity.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${appContext.packageName}"),
                ),
            )
            true
        } catch (_: Exception) {
            try {
                activity.startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:${appContext.packageName}"),
                    ),
                )
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun openUrl(rawUrl: String?): Boolean {
        if (rawUrl.isNullOrEmpty()) return false
        val uri = Uri.parse(rawUrl)
        if (uri.scheme != "https" && uri.scheme != "http") return false
        return try {
            activity.startActivity(
                Intent(Intent.ACTION_VIEW, uri)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun setKeepScreenOn(enabled: Boolean) {
        if (enabled) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().toHex()
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).toHex()

    private fun ByteArray.toHex(): String =
        joinToString("") { byte -> "%02x".format(byte) }

    private fun failed(message: String): Map<String, Any?> =
        mapOf("ok" to false, "message" to message)

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
        setKeepScreenOn(false)
    }

    companion object {
        private const val CHANNEL = "one_page_politics/update"
    }
}
