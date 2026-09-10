import 'dart:convert';

import 'package:esouq/core/error/exceptions.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/package_http_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PackageHttpTransport', () {
    test('sends request and maps response correctly', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.toString(), equals('https://api.esouq.com/items'));
        expect(request.headers['Authorization'], equals('Bearer abc'));
        expect(request.body, equals('{"name":"item"}'));

        return http.Response(
          jsonEncode({'id': '123'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final transport = PackageHttpTransport(client: mockClient);
      final response = await transport.send(
        uri: Uri.parse('https://api.esouq.com/items'),
        method: HttpMethod.post,
        headers: {'Authorization': 'Bearer abc'},
        body: '{"name":"item"}',
      );

      expect(response.statusCode, equals(201));
      expect(response.body, equals('{"id":"123"}'));
      expect(response.headers['content-type'], equals('application/json'));
    });

    test('maps ClientException to NetworkException', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Failed to connect');
      });

      final transport = PackageHttpTransport(client: mockClient);

      expect(
        () => transport.send(
          uri: Uri.parse('https://api.esouq.com/items'),
          method: HttpMethod.get,
          headers: {},
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.message,
          'message',
          contains('Failed to connect'),
        )),
      );
    });

    test('handles request timeout and throws NetworkException', () async {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response('ok', 200);
      });

      final transport = PackageHttpTransport(client: mockClient);

      expect(
        () => transport.send(
          uri: Uri.parse('https://api.esouq.com/items'),
          method: HttpMethod.get,
          headers: {},
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        )),
      );
    });
  });
}
