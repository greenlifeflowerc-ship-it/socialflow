
class AiModel {
  final String id;
  final String name;
  final String displayName;
  final String type;
  final bool isFree;

  AiModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.type,
    this.isFree = false,
  });

  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      id: json['id'],
      name: json['name'],
      displayName: json['displayName'],
      type: json['type'],
      isFree: json['isFree'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'type': type,
      'isFree': isFree,
    };
  }
}
