package com.stdash.hushie_app

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.util.Log
import java.security.MessageDigest
import java.security.NoSuchAlgorithmException
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import android.util.Base64

/**
 * Android应用签名校验服务
 * 用于验证APK签名的完整性，防止应用被篡改或重新打包
 */
class SignatureVerificationService(private val context: Context) {
    
    companion object {
        private const val TAG = "SignatureVerification"
        
        // 单例实例
        @Volatile
        private var INSTANCE: SignatureVerificationService? = null
        
        fun getInstance(context: Context): SignatureVerificationService {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: SignatureVerificationService(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    /**
     * 获取应用签名哈希（用于服务器验证）
     * @return 签名哈希值，如果获取失败返回null
     */
    fun getAppSignatureHash(): String? {
        return try {
            val signatures = getAppSignatures()
            if (signatures.isEmpty()) {
                Log.e(TAG, "无法获取应用签名")
                return null
            }
            
            // 获取第一个签名的哈希值
            val signatureHash = getSignatureHash(signatures[0])
            Log.d(TAG, "当前签名哈希: $signatureHash")
            
            signatureHash
        } catch (e: Exception) {
            Log.e(TAG, "获取签名哈希异常: ${e.message}", e)
            null
        }
    }
    
    /**
     * 生成动态签名字符串
     * @param timestamp 时间戳（毫秒）
     * @param nonce 随机数
     * @param secretKey 与服务器约定的密钥
     * @return 动态签名字符串，如果生成失败返回null
     */
    fun generateDynamicSignature(timestamp: Long, nonce: String, secretKey: String): Map<String, Any>? {
        return try {
            val signatureHash = getAppSignatureHash()
            if (signatureHash == null) {
                Log.e(TAG, "无法获取应用签名哈希")
                return null
            }
            
            // 构建签名原文：签名哈希 + 时间戳 + 随机数 + 密钥
            val rawData = "${signatureHash}|${timestamp}|${nonce}|${secretKey}"
            Log.d(TAG, "签名原文: $rawData")
            
            // 计算HMAC-SHA256
            val hmacSha256 = Mac.getInstance("HmacSHA256")
            val secretKeySpec = SecretKeySpec(secretKey.toByteArray(), "HmacSHA256")
            hmacSha256.init(secretKeySpec)
            
            val signatureBytes = hmacSha256.doFinal(rawData.toByteArray())
            val dynamicSignature = Base64.encodeToString(signatureBytes, Base64.NO_WRAP)
            
            Log.d(TAG, "生成动态签名: $dynamicSignature")
            
            // 返回Map格式的结果
            mapOf(
                "signature" to dynamicSignature,
                "timestamp" to timestamp,
                "nonce" to nonce
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "生成动态签名异常: ${e.message}", e)
            null
        }
    }
    
    /**
     * 验证应用签名（简化版，始终返回true，由服务器端验证）
     * @return 始终返回true，实际验证由服务器完成
     */
    fun verifyAppSignature(): Boolean {
        // 客户端不再进行签名验证，只获取签名信息供服务器验证
        val signatureHash = getAppSignatureHash()
        return signatureHash != null
    }
    
    /**
     * 获取应用的所有签名
     */
    private fun getAppSignatures(): Array<Signature> {
        return try {
            val packageInfo = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNATURES
                )
            }
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.let { signingInfo ->
                    if (signingInfo.hasMultipleSigners()) {
                        signingInfo.apkContentsSigners
                    } else {
                        signingInfo.signingCertificateHistory
                    }
                } ?: emptyArray()
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures ?: emptyArray()
            }
        } catch (e: PackageManager.NameNotFoundException) {
            Log.e(TAG, "包名未找到: ${e.message}", e)
            emptyArray()
        } catch (e: Exception) {
            Log.e(TAG, "获取签名失败: ${e.message}", e)
            emptyArray()
        }
    }
    
    /**
     * 计算签名的SHA-256哈希值
     */
    private fun getSignatureHash(signature: Signature): String {
        return try {
            val digest = MessageDigest.getInstance("SHA-256")
            val hashBytes = digest.digest(signature.toByteArray())
            hashBytes.joinToString("") { "%02X".format(it) }
        } catch (e: NoSuchAlgorithmException) {
            Log.e(TAG, "SHA-256算法不可用: ${e.message}", e)
            ""
        }
    }
    
    /**
     * 获取当前应用的签名信息（用于调试）
     */
    fun getSignatureInfo(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()
        
        try {
            val signatures = getAppSignatures()
            info["signatureCount"] = signatures.size
            
            val signatureHashes = mutableListOf<String>()
            signatures.forEach { signature ->
                val hash = getSignatureHash(signature)
                signatureHashes.add(hash)
            }
            
            info["signatureHashes"] = signatureHashes
            info["packageName"] = context.packageName
            info["isDebugBuild"] = isDebugBuild()
            
        } catch (e: Exception) {
            Log.e(TAG, "获取签名信息失败: ${e.message}", e)
            info["error"] = e.message ?: "未知错误"
        }
        
        return info
    }
    
    /**
     * 检查是否为调试版本
     */
    private fun isDebugBuild(): Boolean {
        return try {
            val applicationInfo = context.applicationInfo
            (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        } catch (e: Exception) {
            Log.e(TAG, "检查调试版本失败: ${e.message}", e)
            false
        }
    }
    
    /**
     * 验证应用完整性（包括签名和安装来源）
     */
    fun verifyAppIntegrity(): AppIntegrityResult {
        val result = AppIntegrityResult()
        
        // 1. 检查签名可用性（实际验证由服务器完成）
        result.isSignatureValid = verifyAppSignature()
        
        // 2. 检查安装来源
        result.installerPackageName = getInstallerPackageName()
        result.isFromTrustedSource = isTrustedInstaller(result.installerPackageName)
        
        // 3. 检查调试状态
        result.isDebugBuild = isDebugBuild()
        
        // 4. 综合评估（基于本地可检查的项目）
        result.isIntegrityValid = result.isSignatureValid && 
                                 (result.isFromTrustedSource || result.isDebugBuild)
        
        Log.i(TAG, "应用完整性验证结果: ${result}")
        return result
    }
    
    /**
     * 获取应用安装来源
     */
    private fun getInstallerPackageName(): String? {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getInstallerPackageName(context.packageName)
            }
        } catch (e: Exception) {
            Log.e(TAG, "获取安装来源失败: ${e.message}", e)
            null
        }
    }
    
    /**
     * 检查是否来自可信的安装源
     */
    private fun isTrustedInstaller(installerPackageName: String?): Boolean {
        val trustedInstallers = setOf(
            "com.android.vending",        // Google Play Store
            "com.android.packageinstaller", // 系统安装器
            "com.google.android.packageinstaller", // Google安装器
            null // 直接安装（开发环境）
        )
        
        return trustedInstallers.contains(installerPackageName)
    }
    
    /**
     * 应用完整性验证结果
     */
    data class AppIntegrityResult(
        var isSignatureValid: Boolean = false,
        var installerPackageName: String? = null,
        var isFromTrustedSource: Boolean = false,
        var isDebugBuild: Boolean = false,
        var isIntegrityValid: Boolean = false
    ) {
        override fun toString(): String {
            return "AppIntegrityResult(" +
                    "signatureValid=$isSignatureValid, " +
                    "installer=$installerPackageName, " +
                    "trustedSource=$isFromTrustedSource, " +
                    "debugBuild=$isDebugBuild, " +
                    "integrityValid=$isIntegrityValid)"
        }
    }
}