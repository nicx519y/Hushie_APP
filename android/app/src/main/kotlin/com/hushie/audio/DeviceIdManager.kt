package com.hushie.audio

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.util.UUID

/**
 * 设备ID管理器
 * - 首次创建一个随机UUID作为设备ID
 * - 保存到 SharedPreferences（便于快速读取）
 * - 尝试写入公共下载目录（MediaStore/Downloads），以在应用卸载后仍可恢复
 */
object DeviceIdManager {
    private const val TAG = "DeviceIdManager"
    private const val PREF_NAME = "persistent_device_id"
    private const val PREF_KEY = "device_id"
    private const val FILE_NAME = "hushie_device_id.txt"
    private val RELATIVE_DOWNLOAD_PATH = Environment.DIRECTORY_DOWNLOADS + "/" // e.g. "Download/"

    fun getOrCreateDeviceId(context: Context): String {
        // 1) 先读 SharedPreferences
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(PREF_KEY, null)
        if (!existing.isNullOrEmpty()) {
            return existing
        }

        // 2) 尝试从公共下载目录恢复
        val restored = tryRestoreFromDownloads(context)
        if (!restored.isNullOrEmpty()) {
            prefs.edit().putString(PREF_KEY, restored).apply()
            return restored
        }

        // 3) 生成新的UUID
        val newId = UUID.randomUUID().toString()
        prefs.edit().putString(PREF_KEY, newId).apply()

        // 4) 尝试写入公共下载目录（在部分设备上可在卸载后保留）
        trySaveToDownloads(context, newId)

        return newId
    }

    private fun tryRestoreFromDownloads(context: Context): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = context.contentResolver

                // 先在 Downloads 集合中按文件名查询
                val downloads = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                val projection = arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME)
                val selection = "${MediaStore.MediaColumns.DISPLAY_NAME}=?"
                val selectionArgs = arrayOf(FILE_NAME)

                val fromDownloads: String? = resolver.query(downloads, projection, selection, selectionArgs, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                        val id = cursor.getLong(idIndex)
                        val uri = Uri.withAppendedPath(downloads, id.toString())
                        resolver.openInputStream(uri)?.use { input ->
                            BufferedReader(InputStreamReader(input)).readLine()?.trim()
                        }
                    } else null
                }

                if (!fromDownloads.isNullOrEmpty()) return fromDownloads

                // 失败则在 Files 集合中回退查询（部分设备/ROM 下载文件可能归于 Files）
                val files = MediaStore.Files.getContentUri("external")
                val fromFiles: String? = resolver.query(files, projection, selection, selectionArgs, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                        val id = cursor.getLong(idIndex)
                        val uri = Uri.withAppendedPath(files, id.toString())
                        resolver.openInputStream(uri)?.use { input ->
                            BufferedReader(InputStreamReader(input)).readLine()?.trim()
                        }
                    } else null
                }

                if (!fromFiles.isNullOrEmpty()) return fromFiles

                // 再次回退：尝试直接路径读取（可能在部分设备上可用）
                @Suppress("DEPRECATION")
                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val legacyFile = File(dir, FILE_NAME)
                if (legacyFile.exists()) legacyFile.readText().trim() else null
            } else {
                @Suppress("DEPRECATION")
                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val file = File(dir, FILE_NAME)
                if (file.exists()) {
                    file.readText().trim()
                } else null
            }
        } catch (e: Exception) {
            Log.w(TAG, "恢复设备ID失败: ${e.message}")
            null
        }
    }

    private fun trySaveToDownloads(context: Context, deviceId: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val contentValues = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, FILE_NAME)
                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                    put(MediaStore.Downloads.IS_PENDING, 1)
                    // 明确指定相对路径到公共下载目录，避免被归入其它集合
                    put(MediaStore.MediaColumns.RELATIVE_PATH, RELATIVE_DOWNLOAD_PATH)
                }

                val resolver: ContentResolver = context.contentResolver
                val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                val itemUri = resolver.insert(collection, contentValues)
                if (itemUri != null) {
                    resolver.openOutputStream(itemUri)?.use { output ->
                        output.write(deviceId.toByteArray())
                        output.flush()
                    }
                    contentValues.clear()
                    contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
                    resolver.update(itemUri, contentValues, null, null)
                }
            } else {
                @Suppress("DEPRECATION")
                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (!dir.exists()) dir.mkdirs()
                val file = File(dir, FILE_NAME)
                file.writeText(deviceId)
            }
            Log.d(TAG, "设备ID已写入公共下载目录")
        } catch (e: Exception) {
            // 在无权限或受限设备上可能失败，忽略但记录日志
            Log.w(TAG, "写入公共下载目录失败: ${e.message}")
        }
    }
}