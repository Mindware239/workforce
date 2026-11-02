import 'package:dio/dio.dart';

/// Checks if an error string contains raw server responses, database errors,
/// stack traces, or technical library jargon that should not be shown to users.
bool isTechnicalMessage(String text) {
  final lower = text.toLowerCase().trim();
  if (lower.isEmpty) return true;

  // Dio & Network technical terms
  if (lower.contains('dioexception') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('network is unreachable') ||
      lower.contains('httpexception') ||
      lower.contains('formatexception') ||
      lower.contains('timeoutexception') ||
      lower.contains('handshakeexception') ||
      lower.contains('certificate_verify_failed') ||
      lower.contains('bad response') ||
      lower.contains('http status error')) {
    return true;
  }

  // Server crash & internal technical terms
  if (lower.contains('internal server error') ||
      lower.contains('bad gateway') ||
      lower.contains('service unavailable') ||
      lower.contains('gateway timeout') ||
      lower.contains('sqlstate') ||
      lower.contains('syntaxerror') ||
      lower.contains('typeerror') ||
      lower.contains('null check operator') ||
      lower.contains('nosuchmethoderror') ||
      lower.contains('instance of') ||
      lower.contains('unhandled exception') ||
      lower.contains('stack trace') ||
      lower.contains('status code of 5') ||
      lower.contains('status code 50') ||
      lower.contains('cannot get /') ||
      lower.contains('cannot post /') ||
      lower.contains('cannot put /') ||
      lower.contains('cannot delete /') ||
      lower.contains('uncaught exception') ||
      lower.contains('call stack')) {
    return true;
  }

  // HTML / XML response bodies
  if (lower.startsWith('<html') ||
      lower.startsWith('<!doctype') ||
      lower.startsWith('<?xml') ||
      lower.contains('</html') ||
      lower.contains('</div>')) {
    return true;
  }

  // Raw JSON dump
  if ((text.startsWith('{') && text.endsWith('}')) ||
      (text.startsWith('[') && text.endsWith(']'))) {
    return true;
  }

  // Stack trace lines
  if (text.contains('\n at ') || text.contains('\nat ') || text.contains('dart:')) {
    return true;
  }

  return false;
}

/// Resolves a relevant, user-friendly error message for the given status or error type.
String resolveFriendlyMessage({
  int? statusCode,
  DioExceptionType? type,
  String? rawMessage,
  String fallback = 'Something went wrong. Please try again.',
}) {
  // Check timeout
  if (type == DioExceptionType.connectionTimeout ||
      type == DioExceptionType.sendTimeout ||
      type == DioExceptionType.receiveTimeout) {
    return 'Connection timed out. Please check your internet connection and try again.';
  }

  // Check connection error
  if (type == DioExceptionType.connectionError) {
    return 'Unable to reach the server. Please check your internet connection.';
  }

  if (type == DioExceptionType.cancel) {
    return 'The request was cancelled.';
  }

  if (type == DioExceptionType.badCertificate) {
    return 'Secure connection error. Please try again later.';
  }

  // HTTP status codes
  if (statusCode != null) {
    // 5xx Server Errors: NEVER show raw response from API
    if (statusCode >= 500) {
      if (statusCode == 502) {
        return 'The server is temporarily unreachable. Please try again later.';
      }
      if (statusCode == 503) {
        return 'The service is temporarily unavailable. Please try again later.';
      }
      if (statusCode == 504) {
        return 'The server took too long to respond. Please try again later.';
      }
      return 'A server error occurred. Please try again later.';
    }

    if (statusCode == 401) {
      return 'Your session has expired. Please log in again.';
    }

    if (statusCode == 403) {
      return 'You do not have permission to perform this action.';
    }

    if (statusCode == 404) {
      return fallback.isNotEmpty ? fallback : 'The requested item was not found.';
    }

    if (statusCode == 429) {
      return 'Too many requests. Please wait a moment and try again.';
    }
  }

  // If a non-technical user-facing message was provided, use it
  if (rawMessage != null && rawMessage.trim().isNotEmpty && !isTechnicalMessage(rawMessage)) {
    return rawMessage.trim();
  }

  return fallback.isNotEmpty ? fallback : 'Something went wrong. Please try again.';
}

/// Turns a failed API call into a relevant, user-friendly message.
///
/// Prevents raw backend error responses (e.g. 500 Internal Server Error, SQL errors,
/// stack traces, or technical jargon) from leaking to the UI.
Exception apiException(Object error, String fallback) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    final type = error.type;
    final data = error.response?.data;

    // 1. Connection and timeout errors
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.connectionError ||
        type == DioExceptionType.cancel ||
        type == DioExceptionType.badCertificate) {
      return Exception(resolveFriendlyMessage(type: type, fallback: fallback));
    }

    // 2. Server 5xx errors: Never show raw API response
    if (statusCode != null && statusCode >= 500) {
      return Exception(resolveFriendlyMessage(statusCode: statusCode, fallback: fallback));
    }

    // 3. Status 401 / 403 / 404 / 429
    if (statusCode == 401 || statusCode == 403 || statusCode == 404 || statusCode == 429) {
      return Exception(resolveFriendlyMessage(statusCode: statusCode, fallback: fallback));
    }

    // 4. For 400 / 422 or client validation errors, extract user-friendly text if not technical
    if (data is Map) {
      final details = data['details'];

      if (details is List && details.isNotEmpty) {
        final first = details.first;

        if (first is Map && first['message'] != null) {
          final text = first['message'].toString().trim();
          if (text.isNotEmpty && !isTechnicalMessage(text)) {
            return Exception(text);
          }
        }
      } else if (details is Map && details.isNotEmpty) {
        final firstVal = details.values.first;
        if (firstVal != null) {
          final text = firstVal.toString().trim();
          if (text.isNotEmpty && !isTechnicalMessage(text)) {
            return Exception(text);
          }
        }
      }

      final message = data['message']?.toString().trim();
      if (message != null && message.isNotEmpty && !isTechnicalMessage(message)) {
        return Exception(message);
      }

      final errorField = data['error']?.toString().trim();
      if (errorField != null && errorField.isNotEmpty && !isTechnicalMessage(errorField)) {
        return Exception(errorField);
      }
    }

    return Exception(resolveFriendlyMessage(statusCode: statusCode, fallback: fallback));
  }

  if (error is Exception) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (isTechnicalMessage(raw)) {
      return Exception(resolveFriendlyMessage(rawMessage: raw, fallback: fallback));
    }
    return error;
  }

  return Exception(fallback.isNotEmpty ? fallback : 'Something went wrong. Please try again.');
}

/// Cleans and transforms any error into a relevant, human-readable message.
///
/// Ensures raw Dio exceptions, stack traces, JSON/HTML dumps, and backend server
/// crash responses are sanitized into clear, relevant errors for screens and snackbars.
String cleanErrorMessage(
  Object? error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error == null) return fallback;

  if (error is DioException) {
    return cleanErrorMessage(apiException(error, fallback), fallback: fallback);
  }

  var message = error.toString().trim();

  // Strip Exception: or Error: prefixes
  if (message.startsWith('Exception: ')) {
    message = message.substring(11).trim();
  }
  if (message.startsWith('Error: ')) {
    message = message.substring(7).trim();
  }

  if (message.isEmpty || isTechnicalMessage(message)) {
    final lower = message.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection') ||
        lower.contains('network')) {
      return 'Unable to reach the server. Please check your internet connection.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Connection timed out. Please check your internet connection.';
    }
    if (lower.contains('internal server error') ||
        lower.contains('status code of 5') ||
        lower.contains('status code 50') ||
        lower.contains('bad gateway') ||
        lower.contains('sqlstate') ||
        lower.contains('service unavailable')) {
      return 'A server error occurred. Please try again later.';
    }
    if (lower.contains('401') || lower.contains('unauthorized') || lower.contains('jwt')) {
      return 'Your session has expired. Please log in again.';
    }
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'You do not have permission to perform this action.';
    }
    return fallback;
  }

  return message;
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
