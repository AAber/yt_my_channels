package live.isaac770.My_YT_Channels

import android.content.Intent
import android.os.Bundle
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.view.KeyEvent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private var channel: MethodChannel? = null
    private var mediaSession: MediaSessionCompat? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "media_buttons")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mediaSession = MediaSessionCompat(this, "MyYTChannels").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            setPlaybackState(
                PlaybackStateCompat.Builder()
                    .setActions(
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
                    )
                    .setState(PlaybackStateCompat.STATE_PLAYING, 0, 1f)
                    .build()
            )
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onMediaButtonEvent(intent: Intent): Boolean {
                    val ke = intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)
                    if (ke != null && ke.action == KeyEvent.ACTION_DOWN) {
                        val action = when (ke.keyCode) {
                            KeyEvent.KEYCODE_MEDIA_PLAY,
                            KeyEvent.KEYCODE_MEDIA_PAUSE,
                            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                            KeyEvent.KEYCODE_HEADSETHOOK -> "play_pause"
                            KeyEvent.KEYCODE_MEDIA_NEXT -> "next"
                            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> "previous"
                            else -> null
                        }
                        if (action != null) {
                            channel?.invokeMethod(action, null)
                            return true
                        }
                    }
                    return super.onMediaButtonEvent(intent)
                }

                override fun onPlay()     { channel?.invokeMethod("play_pause", null) }
                override fun onPause()    { channel?.invokeMethod("play_pause", null) }
                override fun onSkipToNext()     { channel?.invokeMethod("next", null) }
                override fun onSkipToPrevious() { channel?.invokeMethod("previous", null) }
            })
            isActive = true
        }
    }

    override fun onDestroy() {
        mediaSession?.release()
        mediaSession = null
        super.onDestroy()
    }

    // Fallback for wired earphones when activity is foregrounded
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            val action = when (event.keyCode) {
                KeyEvent.KEYCODE_MEDIA_PLAY,
                KeyEvent.KEYCODE_MEDIA_PAUSE,
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                KeyEvent.KEYCODE_HEADSETHOOK -> "play_pause"
                KeyEvent.KEYCODE_MEDIA_NEXT -> "next"
                KeyEvent.KEYCODE_MEDIA_PREVIOUS -> "previous"
                else -> null
            }
            if (action != null) {
                channel?.invokeMethod(action, null)
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
