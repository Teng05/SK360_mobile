import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk360/services/mobile_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Api api;
  late HttpOverrides? previousOverrides;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previousOverrides = HttpOverrides.current;
    api = _Api();
    HttpOverrides.global = api;
  });

  tearDown(() async {
    api.stall = false;
    api.status = 200;
    await MobileApiService.logout();
    HttpOverrides.global = previousOverrides;
  });

  test(
    'successful login opens a session without waiting for dashboard sync',
    () async {
      MobileApiService.syncedData = {'previous_account': true};
      final response = await MobileApiService.login(
        email: 'official@example.com',
        password: 'test-password',
      );

      expect(response['user']['role'], 'sk_chairman');
      expect(MobileApiService.isLoggedIn, isTrue);
      expect(MobileApiService.syncedData, isNull);
      expect(api.paths, ['/api/mobile/login']);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('access_token'), 'test-token');
      expect(
        jsonDecode(preferences.getString('current_user')!)['role'],
        'sk_chairman',
      );

      // The subsequent dashboard refresh can fail without undoing authentication.
      api.status = 503;
      api.body = {'message': 'Sync unavailable'};
      await expectLater(
        MobileApiService.sync(),
        throwsA(isA<MobileApiException>()),
      );
      expect(MobileApiService.isLoggedIn, isTrue);
    },
  );

  test(
    'rejected credentials retain the server error and create no session',
    () async {
      api.status = 422;
      api.body = {'message': 'Invalid email or password.'};
      await expectLater(
        MobileApiService.login(
          email: 'official@example.com',
          password: 'wrong',
        ),
        throwsA(
          isA<MobileApiException>()
              .having((error) => error.statusCode, 'status', 422)
              .having(
                (error) => error.message,
                'message',
                'Invalid email or password.',
              ),
        ),
      );
      expect(MobileApiService.isLoggedIn, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString('access_token'),
        isNull,
      );
    },
  );

  for (final body in [
    <String, dynamic>{},
    {'access_token': '', 'user': {}},
    <dynamic>[],
  ]) {
    test('malformed sign-in response $body creates no session', () async {
      api.body = body;
      await expectLater(
        MobileApiService.login(
          email: 'official@example.com',
          password: 'test-password',
        ),
        throwsA(isA<MobileApiException>()),
      );
      expect(MobileApiService.isLoggedIn, isFalse);
    });
  }

  testWidgets('stalled sign-in times out and closes its connection', (
    tester,
  ) async {
    api.stall = true;
    final expectation = expectLater(
      MobileApiService.login(
        email: 'official@example.com',
        password: 'test-password',
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.message,
          'message',
          contains('took too long'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 31));
    await expectation;
    expect(api.closed, isTrue);
    expect(MobileApiService.isLoggedIn, isFalse);
  });
}

class _Api extends HttpOverrides {
  Object body = {
    'access_token': 'test-token',
    'user': {'role': 'sk_chairman'},
  };
  int status = 200;
  bool stall = false;
  bool closed = false;
  final paths = <String>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(this);
}

class _Client implements HttpClient {
  _Client(this.api);
  final _Api api;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    api.paths.add(url.path);
    if (api.stall) return Completer<HttpClientRequest>().future;
    return _Request(api);
  }

  @override
  void close({bool force = false}) {
    api.closed = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.api);
  final _Api api;

  @override
  HttpHeaders get headers => _Headers();

  @override
  void write(Object? object) {}

  @override
  Future<HttpClientResponse> close() async => _Response(api.body, api.status);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.body, this.statusCode);
  final Object body;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(jsonEncode(body))).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
