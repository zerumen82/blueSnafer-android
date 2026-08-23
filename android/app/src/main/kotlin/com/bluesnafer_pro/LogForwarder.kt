package com.bluesnafer_pro

import io.flutter.plugin.common.EventChannel

/**
 * Forwarder central de logs: mantiene un sink por canal y compone el envío.
 * Orden-independiente: cada EventChannel registra/cancela su propio sink.
 *
 * - 'bluetooth_logs': logs crudos (String)
 * - 'exploit_events': logs como mapas {'type': 'LOG', 'message': ...}
 */
object LogForwarder {
    @Volatile private var rawSink: EventChannel.EventSink? = null
    @Volatile private var mapSink: EventChannel.EventSink? = null

    fun setRawSink(s: EventChannel.EventSink?) {
        rawSink = s
    }

    fun setMapSink(s: EventChannel.EventSink?) {
        mapSink = s
    }

    val sink: EventChannel.EventSink = object : EventChannel.EventSink {
        override fun success(`object`: Any?) {
            rawSink?.success(`object`)
            mapSink?.success(mapOf("type" to "LOG", "message" to `object`.toString()))
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            rawSink?.error(errorCode, errorMessage, errorDetails)
            mapSink?.error(errorCode, errorMessage, errorDetails)
        }

        override fun endOfStream() {
            rawSink?.endOfStream()
            mapSink?.endOfStream()
        }
    }
}
