// Sistema de caché inteligente para BlueSnafer Pro

/// Sistema de caché inteligente para BlueSnafer Pro
class SmartCache<K, V> {
  final Map<K, _CacheEntry<V>> _cache = {};
  final Duration _defaultTtl;
  final int _maxSize;
  final Map<String, dynamic> _stats = {};
  int _lastTotalExecutions = 0;
  final int _lastUpdate = 0;

  SmartCache({
    Duration? defaultTtl,
    int? maxSize,
  })  : _defaultTtl = defaultTtl ?? const Duration(minutes: 30),
        _maxSize = maxSize ?? 1000;

  /// Obtener valor del caché
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    entry.accessCount++;
    entry.lastAccessed = DateTime.now();
    return entry.value;
  }

  /// Establecer valor en caché
  void set(K key, V value, {Duration? ttl}) {
    final expiry = DateTime.now().add(ttl ?? _defaultTtl);

    _cache[key] = _CacheEntry(
      value: value,
      expiry: expiry,
      createdAt: DateTime.now(),
    );

    // Limpiar entradas expiradas si es necesario
    if (_cache.length > _maxSize) {
      _cleanupExpired();
    }

    // Si aún está lleno, eliminar entradas menos usadas
    if (_cache.length > _maxSize) {
      _evictLeastRecentlyUsed();
    }
  }

  /// Verificar si existe en caché y no está expirado
  bool contains(K key) {
    return get(key) != null;
  }

  /// Eliminar entrada del caché
  V? remove(K key) {
    final entry = _cache.remove(key);
    return entry?.value;
  }

  /// Limpiar todas las entradas
  void clear() {
    _cache.clear();
  }

  /// Obtener estadísticas del caché
  Map<String, dynamic> getStats() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _stats['last_update'] < 1000) {
      // Menos de 1 segundo
      return _stats;
    }

    // Calcular nuevo throughput basado en actividad reciente
    final recentExecutions =
        (_stats['total_executions'] ?? 0) - _lastTotalExecutions;
    _lastTotalExecutions = _stats['total_executions'] ?? 0;

    final timeWindowSeconds = (now - (_stats['last_update'] ?? 0)) / 1000;
    final throughput = recentExecutions / timeWindowSeconds;

    _stats['real_time_throughput'] = throughput;
    _stats['last_update'] = now;

    final totalEntries = _cache.length;
    final expiredEntries =
        _cache.values.where((entry) => entry.isExpired).length;
    final activeEntries = totalEntries - expiredEntries;

    final accessCounts =
        _cache.values.map((entry) => entry.accessCount).toList();
    final avgAccessCount = accessCounts.isEmpty
        ? 0.0
        : accessCounts.reduce((a, b) => a + b) / accessCounts.length;

    _stats['total_entries'] = totalEntries;
    _stats['active_entries'] = activeEntries;
    _stats['expired_entries'] = expiredEntries;
    _stats['hit_rate'] = _calculateHitRate();
    _stats['average_access_count'] = avgAccessCount;
    _stats['max_size'] = _maxSize;
    _stats['utilization_percent'] = (totalEntries / _maxSize) * 100;

    return _stats;
  }

  /// Limpiar entradas expiradas
  void _cleanupExpired() {
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }

  /// Eliminar entradas menos usadas (LRU)
  void _evictLeastRecentlyUsed() {
    if (_cache.length <= _maxSize) return;

    final entries = _cache.entries.toList();
    entries
        .sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));

    final toRemove = entries.take(_cache.length - _maxSize + 1);
    for (final entry in toRemove) {
      _cache.remove(entry.key);
    }
  }

  /// Calcular tasa de aciertos (simulada)
  double _calculateHitRate() {
    // Esta es una implementación simplificada
    // En una implementación real, rastrearíamos hits/misses
    final totalAccesses =
        _cache.values.map((entry) => entry.accessCount).reduce((a, b) => a + b);
    return totalAccesses > 0 ? (_cache.length / totalAccesses) * 100 : 0.0;
  }
}

/// Entrada de caché con metadatos
class _CacheEntry<V> {
  final V value;
  final DateTime expiry;
  final DateTime createdAt;
  DateTime lastAccessed;
  int accessCount = 0;

  _CacheEntry({
    required this.value,
    required this.expiry,
    required this.createdAt,
  }) : lastAccessed = createdAt;

  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// Gestor de caché global para la aplicación
class CacheManager {
  static final Map<String, SmartCache> _caches = {};

  /// Obtener caché por nombre
  static SmartCache<K, V> getCache<K, V>(
    String name, {
    Duration? defaultTtl,
    int? maxSize,
  }) {
    if (!_caches.containsKey(name)) {
      _caches[name] = SmartCache<K, V>(
        defaultTtl: defaultTtl,
        maxSize: maxSize,
      );
    }
    return _caches[name]! as SmartCache<K, V>;
  }

  /// Caché para perfiles de dispositivos
  static SmartCache<String, dynamic> get deviceProfilesCache =>
      getCache<String, dynamic>(
        'device_profiles',
        defaultTtl: const Duration(minutes: 30),
        maxSize: 500,
      );

  /// Caché para resultados de vulnerabilidades
  static SmartCache<String, bool> get vulnerabilityCache =>
      getCache<String, bool>(
        'vulnerabilities',
        defaultTtl: const Duration(minutes: 15),
        maxSize: 1000,
      );

  /// Caché para resultados de exploits
  static SmartCache<String, dynamic> get exploitResultsCache =>
      getCache<String, dynamic>(
        'exploit_results',
        defaultTtl: const Duration(minutes: 60),
        maxSize: 200,
      );

  /// Caché para configuraciones dinámicas
  static SmartCache<String, dynamic> get configCache =>
      getCache<String, dynamic>(
        'config',
        defaultTtl: const Duration(hours: 1),
        maxSize: 100,
      );

  /// Limpiar todos los cachés
  static void clearAllCaches() {
    for (final cache in _caches.values) {
      cache.clear();
    }
  }

  /// Obtener estadísticas de todos los cachés
  static Map<String, Map<String, dynamic>> getAllStats() {
    final stats = <String, Map<String, dynamic>>{};

    for (final entry in _caches.entries) {
      stats[entry.key] = entry.value.getStats();
    }

    return stats;
  }

  /// Limpiar cachés expirados
  static void cleanupExpired() {
    for (final cache in _caches.values) {
      // La limpieza se hace automáticamente en get()
      // pero podemos forzar una limpieza aquí si es necesario
    }
  }
}

/// Extensiones útiles para caché
extension CacheExtensions on String {
  /// Obtener del caché de perfiles de dispositivos
  dynamic getDeviceProfile() {
    return CacheManager.deviceProfilesCache.get(this);
  }

  /// Establecer en caché de perfiles de dispositivos
  void setDeviceProfile(dynamic profile, {Duration? ttl}) {
    CacheManager.deviceProfilesCache.set(this, profile, ttl: ttl);
  }

  /// Verificar vulnerabilidad en caché
  bool? getVulnerabilityStatus() {
    return CacheManager.vulnerabilityCache.get(this);
  }

  /// Establecer estado de vulnerabilidad en caché
  void setVulnerabilityStatus(bool vulnerable, {Duration? ttl}) {
    CacheManager.vulnerabilityCache.set(this, vulnerable, ttl: ttl);
  }
}
