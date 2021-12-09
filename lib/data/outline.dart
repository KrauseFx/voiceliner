class Outline {
  Outline(
      {required this.name,
      required this.id,
      required this.dateCreated,
      required this.dateUpdated});
  String name;
  final String id;
  final DateTime dateCreated;
  final DateTime dateUpdated;

  Outline.fromMap(Map<String, dynamic> map)
      : id = map["id"],
        name = map["name"],
        dateCreated = DateTime.fromMillisecondsSinceEpoch(map["date_created"],
            isUtc: true),
        dateUpdated = DateTime.fromMillisecondsSinceEpoch(map["date_updated"],
            isUtc: true);

  Map<String, dynamic> get map {
    return {
      "id": id,
      "name": name,
      "date_created": dateCreated.toUtc().millisecondsSinceEpoch,
      "date_updated": dateCreated.toUtc().millisecondsSinceEpoch
    };
  }
}
