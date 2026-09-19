export 'firebase_functions_stub.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'firebase_functions_stub.dart';

class JsHttpRequest implements HttpRequest {
  final js.JsObject rawReq;
  @override
  final String method;
  @override
  final Map<String, dynamic> headers;
  @override
  final dynamic body;

  JsHttpRequest._(this.rawReq, this.method, this.headers, this.body);

  factory JsHttpRequest(js.JsObject req) {
    final method = (req['method'] as String?) ?? 'GET';

    Map<String, dynamic> headersMap = {};
    final rawHeaders = req['headers'];
    if (rawHeaders != null) {
      try {
        final jsonHeaders =
            js.context['JSON'].callMethod('stringify', [rawHeaders]) as String?;
        if (jsonHeaders != null) {
          headersMap =
              Map<String, dynamic>.from(jsonDecode(jsonHeaders) as Map);
        }
      } catch (_) {}
    }

    dynamic bodyData;
    final rawBody = req['body'];
    if (rawBody != null) {
      if (rawBody is String) {
        try {
          bodyData = jsonDecode(rawBody);
        } catch (_) {
          bodyData = rawBody;
        }
      } else {
        try {
          final jsonBody =
              js.context['JSON'].callMethod('stringify', [rawBody]) as String?;
          if (jsonBody != null) {
            bodyData = jsonDecode(jsonBody);
          }
        } catch (_) {
          bodyData = rawBody;
        }
      }
    }

    return JsHttpRequest._(req, method, headersMap, bodyData);
  }
}

class JsHttpResponse implements HttpResponse {
  final js.JsObject rawRes;

  JsHttpResponse(this.rawRes);

  @override
  HttpResponse status(int code) {
    rawRes.callMethod('status', [code]);
    return this;
  }

  @override
  void json(dynamic data) {
    final jsonStr = jsonEncode(data);
    final jsObj = js.context['JSON'].callMethod('parse', [jsonStr]);
    rawRes.callMethod('json', [jsObj]);
  }

  @override
  void send(String data) {
    rawRes.callMethod('send', [data]);
  }
}

js.JsObject? _resolveCaller;
js.JsObject? _rejectCaller;

js.JsObject get _callResolver => _resolveCaller ??= js.context
    .callMethod('eval', ['(function(r, v) { r(v); })']) as js.JsObject;

js.JsObject get _callRejecter => _rejectCaller ??= js.context
    .callMethod('eval', ['(function(r, e) { r(e); })']) as js.JsObject;

dynamic futureToJsPromise(Future<dynamic> future) {
  final promiseConstructor = js.context['Promise'];
  return js.JsObject(promiseConstructor, [
    js.allowInterop((resolve, reject) {
      future.then(
        (val) {
          final jsVal =
              val is Map || val is Iterable ? js.JsObject.jsify(val) : val;
          _callResolver.callMethod('call', [null, resolve, jsVal]);
        },
        onError: (err, stack) {
          dynamic jsErr = err;
          if (err is! js.JsObject) {
            jsErr = js.JsObject(js.context['Error'], [err.toString()]);
          }
          _callRejecter.callMethod('call', [null, reject, jsErr]);
        },
      );
    })
  ]);
}

dynamic onRequest(
  Map<String, dynamic> options,
  Future<void> Function(HttpRequest, HttpResponse) handler,
) {
  final https = js.context
      .callMethod('require', ['firebase-functions/v2/https']) as js.JsObject;
  final jsOptions = js.JsObject.jsify(options);

  final jsCallback = js.allowInterop((req, res) {
    return futureToJsPromise((() async {
      final httpReq = JsHttpRequest(req as js.JsObject);
      final httpRes = JsHttpResponse(res as js.JsObject);
      await handler(httpReq, httpRes);
    })());
  });

  return https.callMethod('onRequest', [jsOptions, jsCallback]);
}

dynamic onSchedule(
  Map<String, dynamic> options,
  Future<void> Function(dynamic) handler,
) {
  final scheduler =
      js.context.callMethod('require', ['firebase-functions/v2/scheduler'])
          as js.JsObject;
  final jsOptions = js.JsObject.jsify(options);

  final jsCallback = js.allowInterop((event) {
    return futureToJsPromise((() async {
      await handler(event);
    })());
  });

  return scheduler.callMethod('onSchedule', [jsOptions, jsCallback]);
}
