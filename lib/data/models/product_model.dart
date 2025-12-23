/// LEGACY MODEL
/// ------------
/// Represents a flattened inventory view (type|weight -> qty).
/// This model is NOT used for reorder or threshold logic.
/// Will be replaced by nested inventory models in future.
class ProductModel {
  final String id;
  final String category;
  final String item;
  final String name; // display name
  final Map<String, int> weights; // weight key -> quantity in stock
  final Map<String, int> pending; // pending quantities per weight

  ProductModel({
    required this.id,
    required this.category,
    required this.item,
    required this.name,
    required this.weights,
    Map<String, int>? pending,
  }) : pending = pending ?? const {};

  ProductModel copyWith({
    String? id,
    String? category,
    String? item,
    String? name,
    Map<String, int>? weights,
    Map<String, int>? pending,
  }) {
    return ProductModel(
      id: id ?? this.id,
      category: category ?? this.category,
      item: item ?? this.item,
      name: name ?? this.name,
      weights: weights ?? this.weights,
      pending: pending ?? this.pending,
    );
  }

  Map<String, dynamic> toMap() => {
    'category': category,
    'item': item,
    'name': name,
    'weights': weights,
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
        } else if (value is num) {
          parsedWeights[key.toString()] = value.toInt();
        }
      });
    }

    return ProductModel(
      id: id,
      category: map['category'] ?? '',
      item: map['item'] ?? '',
      name: map['name'] ?? '',
      weights: parsedWeights,
    );
  }
}