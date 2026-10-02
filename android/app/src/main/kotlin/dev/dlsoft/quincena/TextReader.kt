package dev.dlsoft.quincena

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.pdf.PdfRenderer
import android.media.ExifInterface
import android.os.ParcelFileDescriptor
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Reads the text in a screenshot, a photo or a PDF, on the device, with
 * ML Kit. Blocks until done: call it off the main thread.
 *
 * The text comes out in rows, top to bottom: a receipt's label and its
 * value side by side read as one line, `Valor  $ 50.000`, which is how
 * `parseCapture` in lib/capture/parser.dart finds the figure that matters.
 * The same as `TextReader.swift` on iOS.
 */
object TextReader {
    private const val LONGEST_SIDE = 3000

    fun read(context: Context, bytes: ByteArray): String =
        if (isPdf(bytes)) readPdf(context, bytes) else readImage(bytes)

    private fun isPdf(bytes: ByteArray): Boolean =
        bytes.size > 4 && String(bytes, 0, 4, Charsets.US_ASCII) == "%PDF"

    private fun readImage(bytes: ByteArray): String {
        val bitmap = decode(bytes) ?: return ""
        return try {
            recognize(bitmap)
        } finally {
            bitmap.recycle()
        }
    }

    /** At most [LONGEST_SIDE] pixels on the longer side, turned the way the
     *  camera says: a photo of a receipt is often sideways. */
    private fun decode(bytes: ByteArray): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / sample > LONGEST_SIDE) sample *= 2
        val bitmap = BitmapFactory.decodeByteArray(
            bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: return null
        val degrees = try {
            when (
                ExifInterface(bytes.inputStream())
                    .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            ) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
        } catch (e: Exception) {
            0
        }
        if (degrees == 0) return bitmap
        val turned = Bitmap.createBitmap(
            bitmap, 0, 0, bitmap.width, bitmap.height,
            Matrix().apply { postRotate(degrees.toFloat()) }, true,
        )
        if (turned != bitmap) bitmap.recycle()
        return turned
    }

    /** The first pages at twice their size on white, enough for small
     *  print. Android has no reader for a PDF's own text. */
    private fun readPdf(context: Context, bytes: ByteArray): String {
        val file = File.createTempFile("quincena-receipt", ".pdf", context.cacheDir)
        return try {
            file.writeBytes(bytes)
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                PdfRenderer(fd).use { renderer ->
                    (0 until min(renderer.pageCount, 3)).joinToString("\n") { i ->
                        renderer.openPage(i).use { page ->
                            val bitmap = Bitmap.createBitmap(
                                page.width * 2, page.height * 2, Bitmap.Config.ARGB_8888,
                            )
                            bitmap.eraseColor(Color.WHITE)
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            try {
                                recognize(bitmap)
                            } finally {
                                bitmap.recycle()
                            }
                        }
                    }
                }
            }
        } finally {
            file.delete()
        }
    }

    private fun recognize(bitmap: Bitmap): String {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        return try {
            rows(Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0))))
        } finally {
            recognizer.close()
        }
    }

    /** Lines at the same height make one row, left to right, two spaces
     *  apart; rows go top to bottom. */
    private fun rows(text: Text): String {
        val lines = text.textBlocks.flatMap { it.lines }
            .mapNotNull { line -> line.boundingBox?.let { it to line.text } }
            .sortedBy { it.first.exactCenterY() }
        val rows = mutableListOf<MutableList<Pair<Rect, String>>>()
        for (line in lines) {
            val first = rows.lastOrNull()?.first()
            if (first != null &&
                abs(first.first.exactCenterY() - line.first.exactCenterY()) <
                min(first.first.height(), line.first.height()) / 2f
            ) {
                rows.last().add(line)
            } else {
                rows.add(mutableListOf(line))
            }
        }
        return rows.joinToString("\n") { row ->
            row.sortedBy { it.first.left }.joinToString("  ") { it.second }
        }
    }
}
