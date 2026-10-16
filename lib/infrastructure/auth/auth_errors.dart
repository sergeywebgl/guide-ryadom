import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../domain/auth.dart';

/// Only enum values cross into diagnostics. Never inspect exception messages,
/// runtime type names, URLs, bodies or stack traces for display or logging.
AuthFailure safeAuthFailure(Object error, AuthStage stage) {
  if (error is AuthFailure) return error.atStage(stage);
  final (code, cause) = switch (error) {
    TimeoutException() => ('timeout', AuthCause.timeout),
    TlsException() => ('tls', AuthCause.tls),
    SocketException() => ('network', AuthCause.socket),
    http.ClientException() => ('network', AuthCause.httpClient),
    HttpException() => ('network', AuthCause.httpClient),
    FormatException() => ('protocol', AuthCause.format),
    StateError() => ('internal', AuthCause.state),
    TypeError() => ('internal', AuthCause.type),
    PlatformException() => ('internal', AuthCause.platform),
    _ => ('internal', AuthCause.unknown),
  };
  return AuthFailure(
    code,
    stage: stage,
    cause: cause,
    // Numeric OS codes only: exclude message, address, port and URL.
    osError: error is SocketException ? error.osError?.errorCode : null,
  );
}
