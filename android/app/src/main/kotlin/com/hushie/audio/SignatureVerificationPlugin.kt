package com.hushie.audio

import android.content.Context
import android.provider.Settings
import android.util.Log
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * 签名验证插件
 * 为Flutter提供Android原生签名验证功能
 */
class SignatureVerificationPlugin : FlutterPlugin, MethodCallHandler {
    
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var signatureService: SignatureVerificationService
    
    companion object {
        private const val CHANNEL_NAME = "app_signature_verification"
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        signatureService = SignatureVerificationService.getInstance(context)
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getAndroidId" -> {
                try {
                    val androidId = Settings.Secure.getString(
                        context.contentResolver,
                        Settings.Secure.ANDROID_ID
                    )
                    Log.d("SignaturePlugin", "ANDROID_ID: $androidId")
                    result.success(androidId)
                } catch (e: Exception) {
                    Log.e("SignaturePlugin", "获取ANDROID_ID失败: ${e.message}", e)
                    result.error("ANDROID_ID_ERROR", "获取ANDROID_ID失败: ${e.message}", e.toString())
                }
            }
            "getPersistentDeviceId" -> {
                try {
                    val id = DeviceIdManager.getOrCreateDeviceId(context)
                    result.success(id)
                } catch (e: Exception) {
                    result.error("DEVICE_ID_ERROR", "获取设备ID失败: ${e.message}", e.toString())
                }
            }
            "verifySignature" -> {
                try {
                    val isValid = signatureService.verifyAppSignature()
                    result.success(isValid)
                } catch (e: Exception) {
                    result.error("SIGNATURE_ERROR", "签名验证失败: ${e.message}", e.toString())
                }
            }
            
            "getIntegrityInfo" -> {
                try {
                    val integrityResult = signatureService.verifyAppIntegrity()
                    val resultMap = mapOf(
                        "isSignatureValid" to integrityResult.isSignatureValid,
                        "installerPackageName" to integrityResult.installerPackageName,
                        "isFromTrustedSource" to integrityResult.isFromTrustedSource,
                        "isDebugBuild" to integrityResult.isDebugBuild,
                        "isIntegrityValid" to integrityResult.isIntegrityValid
                    )
                    result.success(resultMap)
                } catch (e: Exception) {
                    result.error("INTEGRITY_ERROR", "获取完整性信息失败: ${e.message}", e.toString())
                }
            }
            
            // 检查 Google Play 服务可用性（用于在登录前进行设备兼容性预检）
            "isGooglePlayServicesAvailable" -> {
                try {
                    val api = GoogleApiAvailability.getInstance()
                    val status = api.isGooglePlayServicesAvailable(context)
                    val isAvailable = status == ConnectionResult.SUCCESS
                    Log.d("SignaturePlugin", "GMS availability status=$status, available=$isAvailable")
                    result.success(isAvailable)
                } catch (e: Exception) {
                    Log.e("SignaturePlugin", "检查Google Play服务可用性失败: ${e.message}", e)
                    result.success(false)
                }
            }
            
            // 返回更详细的 Google Play 服务状态信息
            "getGooglePlayServicesStatus" -> {
                try {
                    val api = GoogleApiAvailability.getInstance()
                    val status = api.isGooglePlayServicesAvailable(context)
                    val isAvailable = status == ConnectionResult.SUCCESS
                    val isUserResolvable = api.isUserResolvableError(status)
                    var gmsVersionName: String? = null
                    try {
                        val pm = context.packageManager
                        val pi = pm.getPackageInfo("com.google.android.gms", 0)
                        gmsVersionName = pi.versionName
                    } catch (e: Exception) {
                        // 忽略获取版本失败
                    }
                    val map = mapOf(
                        "status" to status,
                        "isAvailable" to isAvailable,
                        "isUserResolvable" to isUserResolvable,
                        "gmsVersionName" to gmsVersionName
                    )
                    result.success(map)
                } catch (e: Exception) {
                    Log.e("SignaturePlugin", "获取GMS状态失败: ${e.message}", e)
                    result.error("GMS_STATUS_ERROR", "获取Google Play服务状态失败: ${e.message}", e.toString())
                }
            }
            
            "getSignatureInfo" -> {
                try {
                    // 返回签名哈希值用于服务器验证
                    val signatureHash = signatureService.getAppSignatureHash()
                    if (signatureHash != null) {
                        result.success("SHA256:$signatureHash")
                    } else {
                        result.success("SIGNATURE_UNAVAILABLE")
                    }
                } catch (e: Exception) {
                    result.error("SIGNATURE_INFO_ERROR", "获取签名信息失败: ${e.message}", e.toString())
                }
            }
            
            "getSignatureDetails" -> {
                try {
                    // 保留原有的详细签名信息方法（用于调试）
                    val signatureInfo = signatureService.getSignatureInfo()
                    result.success(signatureInfo)
                } catch (e: Exception) {
                    result.error("SIGNATURE_DETAILS_ERROR", "获取签名详情失败: ${e.message}", e.toString())
                }
            }
            
            "generateDynamicSignature" -> {
                try {
                    val timestamp = call.argument<Long>("timestamp") ?: 0L
                    val nonce = call.argument<String>("nonce") ?: ""
                    val secretKey = call.argument<String>("secretKey") ?: ""
                    
                    if (timestamp == 0L || nonce.isEmpty() || secretKey.isEmpty()) {
                        result.error("INVALID_PARAMS", "缺少必要的参数", null)
                        return
                    }
                    
                    val signatureResult = signatureService.generateDynamicSignature(timestamp, nonce, secretKey)
                    if (signatureResult != null) {
                        result.success(signatureResult)
                    } else {
                        result.error("SIGNATURE_GENERATION_FAILED", "动态签名生成失败", null)
                    }
                } catch (e: Exception) {
                    result.error("DYNAMIC_SIGNATURE_ERROR", "生成动态签名异常: ${e.message}", e.toString())
                }
            }
            
            "getSignatureHash" -> {
                try {
                    val hash = signatureService.getAppSignatureHash()
                    if (hash != null) {
                        result.success(hash)
                    } else {
                        result.error("SIGNATURE_HASH_ERROR", "无法获取应用签名哈希", null)
                    }
                } catch (e: Exception) {
                    result.error("SIGNATURE_HASH_ERROR", "获取签名哈希失败: ${e.message}", e.toString())
                }
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }
}