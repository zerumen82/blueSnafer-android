package com.bluesnafer_pro

import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

object RootUtils {
    private var _rootChecked = false
    private var _rootAvailable = false
    private var _hciToolAvailable = false
    private var _hciDevices: List<String> = emptyList()

    data class RootResult(
        val success: Boolean,
        val output: String = "",
        val error: String = "",
        val exitCode: Int = -1
    )

    fun isRootAvailable(): Boolean {
        if (!_rootChecked) checkAll()
        return _rootAvailable
    }

    fun isHciToolAvailable(): Boolean {
        if (!_rootChecked) checkAll()
        return _hciToolAvailable
    }

    fun getHciDevices(): List<String> {
        if (!_rootChecked) checkAll()
        return _hciDevices
    }

    fun getRootStatus(): Map<String, Any> {
        if (!_rootChecked) checkAll()
        return mapOf(
            "rootAvailable" to _rootAvailable,
            "hciToolAvailable" to _hciToolAvailable,
            "hciDevices" to _hciDevices,
            "deviceRooted" to File("/system/xbin/su").exists()
        )
    }

    private fun checkAll() {
        _rootChecked = true
        _rootAvailable = checkRootAccess()
        if (_rootAvailable) {
            _hciToolAvailable = checkTool("hcitool")
            _hciDevices = listHciDevices()
        }
    }

    private fun checkRootAccess(): Boolean {
        val suPaths = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su",
            "/system/sd/xbin/su", "/data/local/su", "/data/local/xbin/su",
            "/su/bin/su"
        )
        for (path in suPaths) {
            if (File(path).exists()) return true
        }
        val result = execCommand("which su", useSu = false)
        if (result.success && result.output.isNotBlank()) return true
        val result2 = execCommand("id", useSu = false)
        return result2.success && result2.output.contains("uid=0")
    }

    private fun checkTool(tool: String): Boolean {
        val result = execCommand("which $tool", useSu = true)
        return result.success && result.output.isNotBlank()
    }

    private fun listHciDevices(): List<String> {
        val result = execCommand("hcitool dev", useSu = true)
        if (!result.success) return emptyList()
        return result.output.lines()
            .drop(1)
            .filter { it.isNotBlank() }
            .map { it.trim().split("\\s+".toRegex()).firstOrNull() ?: "" }
            .filter { it.isNotBlank() }
    }

    fun execRoot(command: String): RootResult {
        return execCommand(command, useSu = true)
    }

    fun execRootWithTimeout(command: String, timeoutMs: Long = 30000): RootResult {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", command))
            val stdout = BufferedReader(InputStreamReader(process.inputStream))
            val stderr = BufferedReader(InputStreamReader(process.errorStream))
            val finished = process.waitFor(timeoutMs, TimeUnit.MILLISECONDS)
            if (!finished) {
                process.destroyForcibly()
                return RootResult(false, "", "Command timed out after ${timeoutMs}ms", -1)
            }
            val out = stdout.readText()
            val err = stderr.readText()
            RootResult(process.exitValue() == 0, out, err, process.exitValue())
        } catch (e: Exception) {
            RootResult(false, "", e.message ?: "Unknown error", -1)
        }
    }

    fun sendHciCommand(ogf: String, ocf: String, params: String = ""): RootResult {
        return execRoot("hcitool cmd $ogf $ocf $params")
    }

    fun sendRawAclData(handle: String, pbFlag: String, bcFlag: String, data: String): RootResult {
        return execRoot("hcitool cmd 0x08 0x0006 $handle $pbFlag $bcFlag $data")
    }

    fun readHciDeviceInfo(): RootResult {
        return execRoot("hcitool info")
    }

    fun getConnectionHandle(deviceAddress: String): String? {
        val result = execRoot("hcitool con")
        if (!result.success) return null
        val addrClean = deviceAddress.replace(":", "").lowercase()
        val lines = result.output.lines()
        for (line in lines) {
            if (line.contains(addrClean, ignoreCase = true)) {
                val parts = line.split("\\s+".toRegex())
                for (part in parts) {
                    if (part.startsWith("handle")) {
                        val handle = part.split("=").getOrNull(1)?.trim()?.replace("\\)", "") ?: continue
                        return handle
                    }
                }
            }
        }
        return null
    }

    private fun execCommand(command: String, useSu: Boolean): RootResult {
        return try {
            val cmd = if (useSu) arrayOf("su", "-c", command) else arrayOf("sh", "-c", command)
            val process = Runtime.getRuntime().exec(cmd)
            val stdout = BufferedReader(InputStreamReader(process.inputStream)).readText()
            val stderr = BufferedReader(InputStreamReader(process.errorStream)).readText()
            val exitCode = process.waitFor()
            RootResult(exitCode == 0, stdout.trim(), stderr.trim(), exitCode)
        } catch (e: Exception) {
            RootResult(false, "", e.message ?: "Execution failed", -1)
        }
    }
}
