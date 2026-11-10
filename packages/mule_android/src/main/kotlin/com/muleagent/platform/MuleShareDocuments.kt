package com.muleagent.platform

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.ArrayList
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Provides Android a real ACTION_SEND_MULTIPLE of content:// documents.
 * We deliberately do not include EXTRA_TEXT, which WhatsApp could send
 * alone when presented with a heterogeneous wildcard MIME selection.
 *
 * Each batch uses exact byte copies in a private cache directory, exposed
 * only by temporary read grants for the selected recipient.
 */
class MuleShareDocuments(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "muleagent/share-documents")
    private val worker = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "share") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val entries = call.argument<List<Map<String, String>>>("files")
            if (entries.isNullOrEmpty() || entries.size > 100) {
                result.error("invalid_share", "No hay adjuntos válidos para compartir.", null)
                return@setMethodCallHandler
            }
            worker.execute {
                try {
                    val privateRoot = File(activity.filesDir, "muleagent").canonicalFile
                    val cacheRoot = File(activity.cacheDir, "mule-share-outbox")
                    if (!cacheRoot.isDirectory) check(cacheRoot.mkdirs()) { "No se creó la carpeta temporal de envío." }
                    val batch = File(cacheRoot, UUID.randomUUID().toString())
                    check(batch.mkdirs()) { "No se creó el envío." }
                    // Keep previous batches temporarily: the receiver can read
                    // granted content URIs after the chooser has closed.
                    cacheRoot.listFiles()?.filter {
                        it.isDirectory && it != batch &&
                            System.currentTimeMillis() - it.lastModified() > 7L * 24 * 60 * 60 * 1000
                    }?.forEach { it.deleteRecursively() }
                    val names = HashSet<String>()
                    val uris = ArrayList<Uri>(entries.size)
                    for (entry in entries) {
                        val name = entry["name"] ?: error("Falta el nombre de un archivo.")
                        require(name.matches(Regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,180}$")) &&
                            name != "." && name != ".." && names.add(name)) {
                            "El nombre de un archivo no es válido o está duplicado."
                        }
                        val source = File(entry["source"] ?: error("Falta un archivo.")).canonicalFile
                        require(source.path.startsWith(privateRoot.path + File.separator) &&
                            source.isFile && source.length() > 0L) {
                            "El archivo no existe dentro de la aplicación."
                        }
                        val destination = File(batch, name)
                        source.inputStream().use { input ->
                            destination.outputStream().use { output -> input.copyTo(output) }
                        }
                        check(destination.length() == source.length()) {
                            "La copia de un archivo está incompleta."
                        }
                        uris.add(FileProvider.getUriForFile(
                            activity, "${activity.packageName}.muleagent.share", destination))
                    }
                    activity.runOnUiThread {
                        try {
                            val share = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                                type = "application/octet-stream"
                                putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                                clipData = ClipData.newRawUri("MuleAgent", uris.first()).apply {
                                    for (i in 1 until uris.size) addItem(ClipData.Item(uris[i]))
                                }
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            activity.startActivity(Intent.createChooser(share, "Compartir documentos MuleAgent"))
                            // Success means chooser started, NEVER delivery confirmed.
                            result.success(mapOf("prepared" to uris.size))
                        } catch (e: Exception) {
                            result.error("share_failed", e.message ?: "No se abrió el envío.", null)
                        }
                    }
                } catch (e: Exception) {
                    activity.runOnUiThread {
                        result.error("share_failed", e.message ?: "No se prepararon los adjuntos.", null)
                    }
                }
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}

/** Make images travel as DOCUMENTS, while retaining their .jpg names and bytes. */
class MuleDocumentFileProvider : FileProvider() {
    override fun getType(uri: Uri): String = "application/octet-stream"
}
