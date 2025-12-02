class ProductModel {
  final String id;
  final String name;
  final Map<String, int> weights;
  final int threshold;
  final Map<String, int> pending;

  ProductModel({
    required this.id,
    required this.name,
    required this.weights,
    this.threshold = 5,
    Map<String, int>? pending,
  }) : pending = pending ?? const {};

  ProductModel copyWith({
    String? id,
    String? name,
    Map<String, int>? weights,
    int? threshold,
    Map<String, int>? pending,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      weights: weights ?? this.weights,
      threshold: threshold ?? this.threshold,
      pending: pending ?? this.pending,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'weights': weights,
    'threshold': threshold,
  };

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    final rawWeights = map['weights'];
    final parsedWeights = <String, int>{};

    if (rawWeights is Map) {
      rawWeights.forEach((key, value) {
        if (value is int) {
          parsedWeights[key.toString()] = value;
        } else if (value is String) {
          parsedWeights[key.toString()] = int.tryParse(value) ?? 0;
        }
      });
    }

    return ProductModel(
      id: id,
      name: map['name'] ?? '',
      weights: parsedWeights,
      threshold: (map['threshold'] is int)
          ? map['threshold']
          : int.tryParse(map['threshold']?.toString() ?? '') ?? 5,
    );
  }

  bool isBelowThreshold() {
    return weights.values.any((qty) => qty < threshold);
  }
}