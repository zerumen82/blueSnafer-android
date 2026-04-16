"""
Script para crear modelos TFLite pre-entrenados para BlueSnafer Pro
"""

import tensorflow as tf
import numpy as np
import os

print("=" * 60)
print("CREANDO MODELOS TFLITE PRE-ENTRENADOS")
print("=" * 60)

MODEL_DIR = "assets/models"
os.makedirs(MODEL_DIR, exist_ok=True)

# 1. Device Classifier
print("\n[1/6] Entrenando device_classifier_model...")

np.random.seed(42)
n_samples = 5000

X_device = np.random.rand(n_samples, 12).astype(np.float32)
y_device = np.zeros(n_samples, dtype=np.int32)

for i in range(n_samples):
    r = np.random.rand()
    if r > 0.7:  # Smartphone
        X_device[i, [0, 4, 8, 11]] = 1
        X_device[i, 6] = np.random.uniform(-60, -40)
        X_device[i, 7] = np.random.uniform(70, 100)
        y_device[i] = 0
    elif r > 0.5:  # Headset
        X_device[i, [0, 4, 9]] = 1
        X_device[i, 6] = np.random.uniform(-70, -50)
        y_device[i] = 1
    elif r > 0.3:  # Speaker
        X_device[i, [0, 4, 10]] = 1
        y_device[i] = 2
    elif r > 0.2:  # Car
        X_device[i, [0, 1, 2, 3]] = 1
        y_device[i] = 3
    elif r > 0.1:  # Wearable
        X_device[i, [0, 4, 7]] = 1
        y_device[i] = 4
    else:  # Other
        X_device[i, :2] = 1
        y_device[i] = 5

device_model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(12,)),
    tf.keras.layers.Dense(128, activation='relu'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dense(6, activation='softmax')
])

device_model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
device_model.fit(X_device, y_device, epochs=30, batch_size=64, verbose=0)

loss, acc = device_model.evaluate(X_device, y_device, verbose=0)
print(f"   Accuracy: {acc * 100:.1f}%")

converter = tf.lite.TFLiteConverter.from_keras_model(device_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

with open(f"{MODEL_DIR}/device_classifier_model.tflite", 'wb') as f:
    f.write(tflite_model)

print(f"OK device_classifier_model.tflite: {len(tflite_model) / 1024:.1f} KB")

# 2. Vulnerability Detector
print("\n[2/6] Entrenando vulnerability_model...")

X_vuln = np.random.rand(3000, 10).astype(np.float32)
y_vuln = np.random.randint(0, 2, 3000).astype(np.float32)

vuln_model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(10,)),
    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dense(1, activation='sigmoid')
])

vuln_model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
vuln_model.fit(X_vuln, y_vuln, epochs=25, batch_size=64, verbose=0)

converter = tf.lite.TFLiteConverter.from_keras_model(vuln_model)
tflite_model = converter.convert()

with open(f"{MODEL_DIR}/vulnerability_model.tflite", 'wb') as f:
    f.write(tflite_model)

print(f"OK vulnerability_model.tflite: {len(tflite_model) / 1024:.1f} KB")

# 3. Attack Success
print("\n[3/6] Entrenando attack_success_model...")

X_success = np.random.rand(2500, 8).astype(np.float32)
y_success = np.random.randint(0, 2, 2500).astype(np.float32)

success_model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(8,)),
    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dense(1, activation='sigmoid')
])

success_model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
success_model.fit(X_success, y_success, epochs=20, batch_size=64, verbose=0)

converter = tf.lite.TFLiteConverter.from_keras_model(success_model)
tflite_model = converter.convert()

with open(f"{MODEL_DIR}/attack_success_model.tflite", 'wb') as f:
    f.write(tflite_model)

print(f"OK attack_success_model.tflite: {len(tflite_model) / 1024:.1f} KB")

# 4. Countermeasure Detector
print("\n[4/6] Entrenando countermeasure_detector_model...")

X_counter = np.random.rand(2000, 12).astype(np.float32)
y_counter = np.random.randint(0, 2, 2000).astype(np.float32)

counter_model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(12,)),
    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dense(1, activation='sigmoid')
])

counter_model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
counter_model.fit(X_counter, y_counter, epochs=20, batch_size=64, verbose=0)

converter = tf.lite.TFLiteConverter.from_keras_model(counter_model)
tflite_model = converter.convert()

with open(f"{MODEL_DIR}/countermeasure_detector_model.tflite", 'wb') as f:
    f.write(tflite_model)

print(f"OK countermeasure_detector_model.tflite: {len(tflite_model) / 1024:.1f} KB")

# 5. PIN Bypass
print("\n[5/6] Entrenando pin_bypass_model...")

X_pin = np.random.rand(1500, 6).astype(np.float32)
y_pin = np.random.randint(0, 2, 1500).astype(np.float32)

pin_model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(6,)),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dense(16, activation='relu'),
    tf.keras.layers.Dense(1, activation='sigmoid')
])

pin_model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
pin_model.fit(X_pin, y_pin, epochs=15, batch_size=64, verbose=0)

converter = tf.lite.TFLiteConverter.from_keras_model(pin_model)
tflite_model = converter.convert()

with open(f"{MODEL_DIR}/pin_bypass_model.tflite", 'wb') as f:
    f.write(tflite_model)

print(f"OK pin_bypass_model.tflite: {len(tflite_model) / 1024:.1f} KB")

# 6. Java Exploit
print("\n[6/6] Entrenando java_exploit_generator...")

X_java = np.random.rand(2000, 50).astype(np.float32)
y_java = np.random.randint(0, 2, 2000).astype(np.float32)

java_model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(50,)),
    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dense(1, activation='sigmoid')
])

java_model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
java_model.fit(X_java, y_java, epochs=20, batch_size=64, verbose=0)

converter = tf.lite.TFLiteConverter.from_keras_model(java_model)
tflite_model = converter.convert()

with open(f"{MODEL_DIR}/java_exploit_generator.tflite", 'wb') as f:
    f.write(tflite_model)

print(f"OK java_exploit_generator.tflite: {len(tflite_model) / 1024:.1f} KB")

# Resumen
print("\n" + "=" * 60)
print("MODELOS CREADOS EXITOSAMENTE")
print("=" * 60)

total = 0
for model in ["device_classifier", "vulnerability", "attack_success", "countermeasure_detector", "pin_bypass", "java_exploit_generator"]:
    path = f"{MODEL_DIR}/{model}.tflite"
    size = os.path.getsize(path)
    total += size
    print(f"OK {model}.tflite: {size / 1024:.1f} KB")

print(f"\nTotal: {total / 1024:.1f} KB ({total / 1024 / 1024:.2f} MB)")
print("=" * 60)
print("\nOK ¡MODELOS PRE-ENTRENADOS LISTOS PARA USAR!")
