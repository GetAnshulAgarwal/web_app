import 'dart:convert';

// Top-level functions for use with compute() to parse JSON off the UI thread.
Map<String, dynamic> parseJsonToMap(String body) {
  final decoded = json.decode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  return <String, dynamic>{};
}

List<dynamic> parseJsonToList(String body) {
  final decoded = json.decode(body);
  if (decoded is List) return decoded;
  return <dynamic>[];
}

// Generic parser that returns whatever json.decode produces (Map/List/etc).
dynamic parseJson(String body) {
  return json.decode(body);
}
// import 'dart:convert';

/// Top-level helpers for compute() to decode JSON in background isolates.
/// Return types are primitive (Map/List) so they can be sent across isolate
/// boundaries without errors.

Map<String, dynamic> parseJsonMap(String jsonString) {
  return json.decode(jsonString) as Map<String, dynamic>;
}

List<dynamic> parseJsonList(String jsonString) {
  return json.decode(jsonString) as List<dynamic>;
}

dynamic parseJsonDynamic(String jsonString) {
  return json.decode(jsonString);
}
