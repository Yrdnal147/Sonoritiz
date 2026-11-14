package com.example.sonoritiz

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.util.Log
import android.view.KeyEvent
import androidx.media.session.MediaButtonReceiver
import java.io.File

object WidgetBitmapHelper {

    /**
     * Décode un fichier image local en réduisant sa résolution (sous-échantillonnage + RGB_565)
     * afin de ne jamais dépasser la limite Binder IPC (~1 Mo) des RemoteViews Android
     * et d'éviter tout OutOfMemoryError ou TransactionTooLargeException.
     */
    fun decodeSampledBitmap(path: String?, maxDim: Int): Bitmap? {
        if (path.isNullOrEmpty() || maxDim <= 0) return null
        return try {
            val cleanPath = if (path.startsWith("file://")) path.removePrefix("file://") else path
            val file = File(cleanPath)
            if (!file.exists() || !file.canRead() || file.length() <= 0L) return null

            val boundsOptions = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeFile(file.absolutePath, boundsOptions)

            val srcW = boundsOptions.outWidth
            val srcH = boundsOptions.outHeight
            if (srcW <= 0 || srcH <= 0) return null

            var sampleSize = 1
            while ((srcW / (sampleSize * 2)) >= maxDim || (srcH / (sampleSize * 2)) >= maxDim) {
                sampleSize *= 2
            }

            val decodeOptions = BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = Bitmap.Config.RGB_565
            }

            val decoded = BitmapFactory.decodeFile(file.absolutePath, decodeOptions) ?: return null
            if (decoded.width <= maxDim && decoded.height <= maxDim) {
                return decoded
            }

            val scale = maxDim.toFloat() / maxOf(decoded.width, decoded.height).toFloat()
            val targetW = (decoded.width * scale).toInt().coerceAtLeast(1)
            val targetH = (decoded.height * scale).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(decoded, targetW, targetH, true)
            if (scaled !== decoded) {
                decoded.recycle()
            }
            scaled
        } catch (e: Throwable) {
            Log.e("WidgetBitmapHelper", "Erreur décodage miniature widget: ${e.message}")
            null
        }
    }

    /**
     * Construit un PendingIntent explicite ciblant MediaButtonReceiver d'AndroidX Media,
     * garantissant la réception des boutons Play/Pause/Suivant/Précédent même sur Android 8+ / 14+.
     */
    fun buildMediaPendingIntent(
        context: Context,
        keyCode: Int,
        requestCodeOffset: Int = 0
    ): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = ComponentName(context, MediaButtonReceiver::class.java)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCodeOffset + keyCode, intent, flags)
    }

    /**
     * Découpe un Bitmap en cercle parfait avec antialiasing pour l'avatar artiste du widget.
     */
    fun createCircularBitmap(src: Bitmap?): Bitmap? {
        if (src == null) return null
        return try {
            val size = minOf(src.width, src.height)
            if (size <= 0) return src
            val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                isFilterBitmap = true
            }
            val srcRect = Rect(
                (src.width - size) / 2,
                (src.height - size) / 2,
                (src.width + size) / 2,
                (src.height + size) / 2
            )
            val destRectF = RectF(0f, 0f, size.toFloat(), size.toFloat())
            canvas.drawOval(destRectF, paint)
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            canvas.drawBitmap(src, srcRect, destRectF, paint)
            output
        } catch (e: Throwable) {
            Log.e("WidgetBitmapHelper", "Erreur createCircularBitmap: ${e.message}")
            src
        }
    }
}
