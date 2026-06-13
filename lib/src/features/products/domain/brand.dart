class Brand {
  final String name;
  final String logoUrl;

  Brand({
    required this.name,
    required this.logoUrl,
  });

  factory Brand.fromMap(Map<String, dynamic> map) {
    return Brand(
      name: map['name'] as String? ?? '',
      logoUrl: map['logoUrl'] as String? ?? '',
    );
  }
}
