abstract class HttpRequest {
  String get method;
  Map<String, dynamic> get headers;
  dynamic get body;
}

abstract class HttpResponse {
  HttpResponse status(int code);
  void json(dynamic data);
  void send(String data);
}

class TestHttpRequest implements HttpRequest {
  @override
  final String method;
  @override
  final Map<String, dynamic> headers;
  @override
  final dynamic body;

  TestHttpRequest({
    this.method = 'GET',
    this.headers = const {},
    this.body,
  });
}

class TestHttpResponse implements HttpResponse {
  int statusCode = 200;
  dynamic responseData;
  String? sentData;

  @override
  HttpResponse status(int code) {
    statusCode = code;
    return this;
  }

  @override
  void json(dynamic data) {
    responseData = data;
  }

  @override
  void send(String data) {
    sentData = data;
  }
}

dynamic onRequest(
  Map<String, dynamic> options,
  Future<void> Function(HttpRequest, HttpResponse) handler,
) {
  throw UnsupportedError('onRequest is only available when compiled to JS.');
}

dynamic onSchedule(
  Map<String, dynamic> options,
  Future<void> Function(dynamic) handler,
) {
  throw UnsupportedError('onSchedule is only available when compiled to JS.');
}
