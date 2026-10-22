import 'package:dio/dio.dart';

/// Turns a failed API call into the message the backend sent.
///
/// The API answers errors as `{ success, statusCode, message, details }`;
/// validation failures carry `message: "Validation failed"` and the useful
/// text in `details[].message`, so that one is preferred when present.
Exception apiException(Object error, String fallback) {
  if (error is DioException) {
    final data = error.response?.data;

    if (data is Map) {
      final details = data['details'];

      if (details is List && details.isNotEmpty) {
        final first = details.first;

        if (first is Map && first['message'] != null) {
          final text = first['message'].toString().trim();

          if (text.isNotEmpty) return Exception(text);
        }
      }

      final message = data['message']?.toString().trim();

      if (message != null && message.isNotEmpty) {
        return Exception(message);
      }
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return Exception('Unable to reach the server. Check your connection.');
    }

    return Exception(fallback);
  }

  if (error is Exception) return error;

  return Exception(fallback);
}

/// `Exception: foo` -> `foo`, as the existing notifiers do.
String cleanErrorMessage(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '').trim();

  return message.isEmpty ? 'Something went wrong.' : message;
}

/// The `data` of a standard API response, or the body itself.
dynamic unwrapData(dynamic body) {
  if (body is Map && body.containsKey('data')) return body['data'];

  return body;
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);

  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  return [];
}
