import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/auth.dart';
import 'oauth_contract.dart';

const _channel = MethodChannel('guide_ryadom/auth');

class AndroidAuthVault implements AuthVault {
  @override
  Future<String> hostId() async =>
      (await _channel.invokeMethod<String>('hostId'))!;
  @override
  Future<String?> read() => _channel.invokeMethod<String>('readVault');
  @override
  Future<void> write(String value) =>
      _channel.invokeMethod<void>('writeVault', value);
}

class AndroidSystemBrowser implements SystemBrowser {
  @override
  Future<void> open(Uri uri) async {
    try {
      await _channel.invokeMethod<void>('openBrowser', uri.toString());
    } catch (_) {
      throw const AuthFailure('browser');
    }
  }
}

/// Bind only IPv4 loopback, never all interfaces. No custom-scheme fallback.
class LoopbackReceiver implements CallbackReceiver {
  HttpServer? _server;
  final _result = Completer<Uri>();
  bool _received = false;
  @override
  Future<Uri> get callback => _result.future;
  @override
  Future<Uri> start() async {
    try {
      final server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: false,
      );
      _server = server;
      server.listen(
        (request) async {
          Uri? callbackUri;
          request.response.headers
            ..contentType = ContentType.html
            ..set('Cache-Control', 'no-store')
            ..set(
              'Content-Security-Policy',
              "default-src 'none'; frame-ancestors 'none'",
            )
            ..set('Referrer-Policy', 'no-referrer');
          if (request.method != 'GET' ||
              request.uri.path != '/auth/callback' ||
              request.headers.value('host') != '127.0.0.1:${server.port}' ||
              _received) {
            request.response.statusCode = 404;
          } else {
            _received = true;
            callbackUri = Uri.parse(
              'http://127.0.0.1:${server.port}${request.uri}',
            );
            request.response.write(
              '<!doctype html><meta charset="utf-8"><title>Guide Ryadom</title><p>Ответ получен. Вернитесь в приложение «Гид рядом» для проверки результата.</p>',
            );
          }
          try {
            await request.response.close();
          } catch (_) {
            /* Browser may close the tab. */
          }
          if (callbackUri != null && !_result.isCompleted) {
            _result.complete(callbackUri);
          }
        },
        onError: (Object _) {
          if (!_result.isCompleted) {
            _result.completeError(const AuthFailure('loopback'));
          }
        },
      );
      return Uri.parse('http://127.0.0.1:${server.port}/auth/callback');
    } catch (_) {
      throw const AuthFailure('loopback');
    }
  }

  @override
  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }
}
