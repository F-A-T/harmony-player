package com.example.harmony_player

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.ffmpeg.FFmpeg
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import kotlin.random.Random

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.example.harmony_player/youtube"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize YoutubeDL and update to latest yt-dlp to break bot protection
        GlobalScope.launch(Dispatchers.IO) {
            try {
                YoutubeDL.getInstance().init(application)
                FFmpeg.getInstance().init(application)
                YoutubeDL.getInstance().updateYoutubeDL(application, YoutubeDL.UpdateChannel.STABLE)
            } catch (e: Exception) {
                println("YoutubeDL initialization error: ${e.message}")
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getStreamUrl") {
                val videoId = call.argument<String>("videoId")
                if (videoId != null) {
                    GlobalScope.launch(Dispatchers.IO) {
                        try {
                            // Cihaz yavaşsa ve henüz init olmadıysa burada garanti altına alıyoruz
                            try {
                                YoutubeDL.getInstance().init(application)
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("INIT_ERROR", "Gökkuşağı hatası: " + e.message, e.stackTraceToString())
                                }
                                return@launch
                            }

                            val request = YoutubeDLRequest("https://www.youtube.com/watch?v=$videoId")
                            // ExoPlayer takılmalarını önlemek için m4a ağırlık veriyoruz
                            request.addOption("-f", "bestaudio[ext=m4a]/bestaudio")
                            val streamInfo = YoutubeDL.getInstance().getInfo(request)
                            
                            withContext(Dispatchers.Main) {
                                if (streamInfo.url != null) result.success(streamInfo.url)
                                else result.error("ERROR", "URL extraction failed", null)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("ERROR", e.message, null)
                            }
                        }
                    }
                } else {
                    result.error("INVALID_ID", "Video ID is null", null)
                }
            } else if (call.method == "downloadAudio") {
                val videoId = call.argument<String>("videoId")
                val downloadPath = call.argument<String>("downloadPath")
                
                if (videoId != null && downloadPath != null) {
                    GlobalScope.launch(Dispatchers.IO) {
                        try {
                            try {
                                YoutubeDL.getInstance().init(application)
                                FFmpeg.getInstance().init(application)
                            } catch (e: Exception) {}

                            val request = YoutubeDLRequest("https://www.youtube.com/watch?v=$videoId")
                            request.addOption("-o", downloadPath)
                            request.addOption("-x")
                            request.addOption("--audio-format", "mp3")
                            request.addOption("--audio-quality", "192K")
                            request.addOption("--embed-thumbnail")
                            request.addOption("--add-metadata")
                            
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val channel = NotificationChannel("download_channel", "İndirmeler", NotificationManager.IMPORTANCE_LOW)
                                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                                manager.createNotificationChannel(channel)
                            }
                            
                            val notificationId = Random.nextInt()
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            val builder = NotificationCompat.Builder(this@MainActivity, "download_channel")
                                .setSmallIcon(android.R.drawable.stat_sys_download)
                                .setContentTitle("İndiriliyor...")
                                .setContentText("Şarkı hazırlanıyor")
                                .setPriority(NotificationCompat.PRIORITY_LOW)
                                .setOngoing(true)

                            notificationManager.notify(notificationId, builder.build())
                            
                            YoutubeDL.getInstance().execute(request) { progress, etaInSeconds, line ->
                                builder.setProgress(100, progress.toInt(), false)
                                builder.setContentText("%$progress ($etaInSeconds sn kaldı)")
                                notificationManager.notify(notificationId, builder.build())
                            }
                            
                            builder.setContentTitle("İndirme Tamamlandı")
                                   .setContentText("Kütüphaneye eklendi")
                                   .setProgress(0, 0, false)
                                   .setOngoing(false)
                                   .setSmallIcon(android.R.drawable.stat_sys_download_done)
                            notificationManager.notify(notificationId, builder.build())

                            withContext(Dispatchers.Main) {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("DOWNLOAD_ERROR", e.message, null)
                            }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

