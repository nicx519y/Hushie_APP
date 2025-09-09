package com.stdash.hushie_app

import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.stdash.hushie_app/exoplayer_config"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        // 立即设置主题为正常主题，跳过启动页
        setTheme(androidx.appcompat.R.style.Theme_AppCompat_NoActionBar)
        super.onCreate(savedInstanceState)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "configureExoPlayerBuffer" -> {
                    val minBufferMs = call.argument<Int>("minBufferMs") ?: 2000
                    val maxBufferMs = call.argument<Int>("maxBufferMs") ?: 300000 // 300秒
                    
                    // 配置 ExoPlayer 缓冲参数
                    configureExoPlayerBuffer(minBufferMs, maxBufferMs)
                    result.success("ExoPlayer buffer configured: min=${minBufferMs}ms, max=${maxBufferMs}ms")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun configureExoPlayerBuffer(minBufferMs: Int, maxBufferMs: Int) {
        // 通过系统属性设置 ExoPlayer 缓冲参数
        // 这些属性会被 just_audio 插件读取
        System.setProperty("exoplayer.min_buffer_ms", minBufferMs.toString())
        System.setProperty("exoplayer.max_buffer_ms", maxBufferMs.toString())
        //- 含义 ：开始播放所需的最小缓冲时间
        //- 当前设置 ：2500ms（2.5秒）
        //- 作用 ：音频必须缓冲至少 2.5 秒才开始播放，确保播放开始时有足够的数据避免卡顿
        //- 影响 ：较小的值可以更快开始播放，但可能增加播放中断风险；较大的值播放更稳定但启动较慢
        System.setProperty("exoplayer.buffer_for_playback_ms", "2500") 
        //- 含义 ：重新缓冲后恢复播放所需的缓冲时间
        //- 当前设置 ：300000ms（300秒 = 5分钟）
        //- 作用 ：当播放因网络问题中断后，需要缓冲 5 分钟的内容才恢复播放
        //- 影响 ：确保重新开始播放后有充足的缓冲，避免频繁中断
        System.setProperty("exoplayer.buffer_for_playback_after_rebuffer_ms", "2500") // 300000ms 缓冲（5分钟）
    }
}