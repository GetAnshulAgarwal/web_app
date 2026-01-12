class CacheMetadata {
  final String key;
  final DateTime cachedAt;
  final DateTime expiresAt;
  final int version;
  final String checksum;

  CacheMetadata({
    required this.key,
    required this.cachedAt,
    required this.expiresAt,
    this.version = 1,
    this.checksum = '',
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'cachedAt': cachedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'version': version,
    'checksum': checksum,
  };

  factory CacheMetadata.fromJson(Map<String, dynamic> json) => CacheMetadata(
    key: json['key']?.toString() ?? '',
    cachedAt: DateTime.parse(
      json['cachedAt'] ?? DateTime.now().toIso8601String(),
    ),
    expiresAt: DateTime.parse(
      json['expiresAt'] ?? DateTime.now().toIso8601String(),
    ),
    version:
        (json['version'] is int)
            ? json['version'] as int
            : int.tryParse(json['version']?.toString() ?? '1') ?? 1,
    checksum: json['checksum']?.toString() ?? '',
  );
}
