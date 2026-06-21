import 'api_error.dart';

class JsonReader {
  const JsonReader(this._json, {this.context = 'JSON payload'});

  factory JsonReader.fromObject(
      Object? value, {
        String context = 'JSON payload',
      }) {
    if (value is Map) {
      final normalized = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw ApiException(
            ApiError(
              code: ApiErrorCode.malformedPayload,
              message: '$context contains a non-string key.',
            ),
          );
        }
        normalized[entry.key as String] = entry.value;
      }
      return JsonReader(normalized, context: context);
    }

    throw ApiException(
      ApiError(
        code: ApiErrorCode.malformedPayload,
        message: '$context must be a JSON object.',
      ),
    );
  }

  final Map<String, Object?> _json;
  final String context;

  String requiredString(String key) {
    final value = _json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw _invalidField(key, 'a non-empty string');
  }

  String? optionalString(String key) {
    final value = _json[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw _invalidField(key, 'a string or null');
  }

  int requiredInt(String key) {
    final value = _json[key];
    if (value is int) {
      return value;
    }
    throw _invalidField(key, 'an integer');
  }

  int requiredPositiveInt(String key) {
    final value = requiredInt(key);
    if (value > 0) {
      return value;
    }
    throw _invalidField(key, 'a positive integer');
  }

  int requiredNonNegativeInt(String key) {
    final value = requiredInt(key);
    if (value >= 0) {
      return value;
    }
    throw _invalidField(key, 'a non-negative integer');
  }

  int optionalInt(String key, {required int defaultValue}) {
    final value = _json[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is int) {
      return value;
    }
    throw _invalidField(key, 'an integer or null');
  }

  int? optionalPositiveInt(String key) {
    final value = _json[key];
    if (value == null) {
      return null;
    }
    if (value is int && value > 0) {
      return value;
    }
    throw _invalidField(key, 'a positive integer or null');
  }

  int? optionalNullableInt(String key) {
    final value = _json[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    throw _invalidField(key, 'an integer or null');
  }

  double requiredDouble(String key) {
    final value = _json[key];
    if (value is num) {
      return value.toDouble();
    }
    throw _invalidField(key, 'a number');
  }

  double optionalDouble(String key, {required double defaultValue}) {
    final value = _json[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is num) {
      return value.toDouble();
    }
    throw _invalidField(key, 'a number or null');
  }

  int optionalNonNegativeInt(String key, {required int defaultValue}) {
    final value = _json[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is int && value >= 0) {
      return value;
    }
    throw _invalidField(key, 'a non-negative integer or null');
  }

  double optionalNonNegativeDouble(
      String key, {
        required double defaultValue,
      }) {
    final value = _json[key];

    if (value == null) {
      return defaultValue;
    }

    if (value is num && value >= 0) {
      return value.toDouble();
    }

    throw _invalidField(key, 'a non-negative number or null');
  }

  bool requiredBool(String key) {
    final value = _json[key];
    if (value is bool) {
      return value;
    }
    throw _invalidField(key, 'a boolean');
  }

  bool optionalBool(String key, {required bool defaultValue}) {
    final value = _json[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is bool) {
      return value;
    }
    throw _invalidField(key, 'a boolean or null');
  }

  DateTime requiredDateTime(String key) {
    final value = requiredString(key);
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
    throw _invalidField(key, 'an ISO-8601 date-time string');
  }

  DateTime? optionalDateTime(String key) {
    final value = optionalString(key);
    if (value == null) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
    throw _invalidField(key, 'an ISO-8601 date-time string or null');
  }

  DateTime requiredDate(String key) {
    final value = requiredString(key);
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    throw _invalidField(key, 'an ISO-8601 date string');
  }

  JsonReader requiredObject(String key) {
    return JsonReader.fromObject(_json[key], context: '$context.$key');
  }

  List<JsonReader> requiredObjectList(String key) {
    final value = _json[key];
    if (value is! List) {
      throw _invalidField(key, 'a list of objects');
    }
    return value
        .asMap()
        .entries
        .map(
          (entry) => JsonReader.fromObject(
        entry.value,
        context: '$context.$key[${entry.key}]',
      ),
    )
        .toList(growable: false);
  }

  List<JsonReader> optionalObjectList(String key) {
    final value = _json[key];
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      throw _invalidField(key, 'a list of objects or null');
    }
    return value
        .asMap()
        .entries
        .map(
          (entry) => JsonReader.fromObject(
        entry.value,
        context: '$context.$key[${entry.key}]',
      ),
    )
        .toList(growable: false);
  }

  List<String> optionalStringList(String key) {
    final value = _json[key];
    if (value == null) {
      return const [];
    }
    if (value is! List || value.any((item) => item is! String)) {
      throw _invalidField(key, 'a list of strings or null');
    }
    return List<String>.unmodifiable(value.cast<String>());
  }

  List<int> optionalIntList(String key) {
    final value = _json[key];
    if (value == null) {
      return const [];
    }
    if (value is! List || value.any((item) => item is! int)) {
      throw _invalidField(key, 'a list of integers or null');
    }
    return List<int>.unmodifiable(value.cast<int>());
  }

  List<DateTime> optionalDateTimeList(String key) {
    final value = _json[key];
    if (value == null) {
      return const [];
    }
    if (value is! List || value.any((item) => item is! String)) {
      throw _invalidField(key, 'a list of ISO-8601 date-time strings or null');
    }

    return List<DateTime>.unmodifiable(
      value.cast<String>().map((item) {
        final parsed = DateTime.tryParse(item);
        if (parsed == null) {
          throw _invalidField(key, 'a list of ISO-8601 date-time strings');
        }
        return parsed;
      }),
    );
  }

  Map<String, Object?> objectOrEmpty(String key) {
    final value = _json[key];
    if (value == null) {
      return const {};
    }
    return JsonReader.fromObject(value, context: '$context.$key').toMap();
  }

  Map<String, Object?> toMap() => Map.unmodifiable(_json);

  ApiException _invalidField(String key, String expected) {
    return ApiException(
      ApiError(
        code: ApiErrorCode.malformedPayload,
        message: '$context.$key must be $expected.',
        details: {'field': key, 'expected': expected},
      ),
    );
  }
}