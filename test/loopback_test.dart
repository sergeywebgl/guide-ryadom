import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guide_ryadom/infrastructure/auth/android_auth.dart';

void main() {
  test(
    'real local listener rejects wrong path and accepts loopback callback',
    () async {
      final receiver = LoopbackReceiver();
      final client = HttpClient();
      addTearDown(() {
        client.close(force: true);
        return receiver.close();
      });
      final redirect = await receiver.start();
      expect(redirect.host, '127.0.0.1');
      expect(redirect.port, greaterThan(0));
      final wrong = await (await client.getUrl(
        redirect.replace(path: '/other'),
      )).close();
      expect(wrong.statusCode, 404);
      await wrong.drain<void>();
      final callback = redirect.replace(
        queryParameters: {'code': 'mock-code', 'state': 'mock-state'},
      );
      final response = await (await client.getUrl(callback)).close();
      expect(response.statusCode, 200);
      expect(response.headers.value('cache-control'), 'no-store');
      await response.drain<void>();
      expect(await receiver.callback, callback);
      await receiver.close();
      await receiver.close();
    },
  );
}
