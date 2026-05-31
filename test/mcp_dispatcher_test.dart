import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/mcp/mcp_types.dart';
import 'package:planom/src/mcp/mcp_dispatcher.dart';

void main() {
  McpDispatcher buildDispatcher() => McpDispatcher(
        serverInfo: const McpServerInfo(name: 'test-server', version: '9.9.9'),
        handlers: {
          'echo': (args) async => 'hi ${args['x']}',
          'boom': (args) async => throw Exception('handler exploded'),
        },
      );

  group('McpDispatcher.handle', () {
    test('initialize returns server info with no error', () async {
      final d = buildDispatcher();
      final res = await d.handle(McpRequest(method: 'initialize', id: 1));
      expect(res.error, isNull);
      expect(res.id, 1);
      final result = res.result as Map<String, dynamic>;
      final info = result['serverInfo'] as Map<String, dynamic>;
      expect(info['name'], 'test-server');
      expect(info['version'], '9.9.9');
      expect(result['protocolVersion'], '2024-11-05');
    });

    test('tools/list returns a non-empty default tools list', () async {
      final d = buildDispatcher();
      final res = await d.handle(McpRequest(method: 'tools/list', id: 2));
      expect(res.error, isNull);
      final result = res.result as Map<String, dynamic>;
      final tools = result['tools'] as List;
      expect(tools, isNotEmpty);
      // Each tool entry has a name + inputSchema.
      final first = tools.first as Map<String, dynamic>;
      expect(first['name'], isA<String>());
      expect(first['inputSchema'], isA<Map>());
    });

    test('tools/call wraps the handler return into text content', () async {
      final d = buildDispatcher();
      final res = await d.handle(McpRequest(
        method: 'tools/call',
        id: 3,
        params: <String, dynamic>{
          'name': 'echo',
          'arguments': <String, dynamic>{'x': 'bob'},
        },
      ));
      expect(res.error, isNull);
      // The dispatcher wraps the handler's String into an McpToolResult.
      final result = res.result as McpToolResult;
      expect(result.isError, isFalse);
      final block = result.content.first;
      expect(block['type'], 'text');
      expect(block['text'], 'hi bob');
      // And it serialises to the MCP content-block shape.
      final json = result.toJson();
      expect((json['content'] as List).first, block);
    });

    test('a throwing handler becomes an isError tool result', () async {
      final d = buildDispatcher();
      final res = await d.handle(McpRequest(
        method: 'tools/call',
        id: 4,
        params: <String, dynamic>{'name': 'boom', 'arguments': <String, dynamic>{}},
      ));
      // Handler exceptions are caught and surfaced as isError results, not as
      // JSON-RPC errors.
      expect(res.error, isNull);
      final result = res.result as McpToolResult;
      expect(result.isError, isTrue);
      expect(result.content.first['text'], contains('handler exploded'));
    });

    test('unknown method returns method-not-found error', () async {
      final d = buildDispatcher();
      final res = await d.handle(McpRequest(method: 'no/such/method', id: 5));
      expect(res.result, isNull);
      expect(res.error, isNotNull);
      expect(res.error!.code, McpError.methodNotFound.code);
    });

    test('tools/call with unknown tool returns method-not-found error',
        () async {
      final d = buildDispatcher();
      final res = await d.handle(McpRequest(
        method: 'tools/call',
        id: 6,
        params: <String, dynamic>{'name': 'nope', 'arguments': <String, dynamic>{}},
      ));
      // Per dispatcher: unknown tool is a JSON-RPC error (not an isError
      // result). The tool name is carried in the error's `data`.
      expect(res.result, isNull);
      expect(res.error, isNotNull);
      expect(res.error!.code, McpError.methodNotFound.code);
      expect(res.error!.data, contains('nope'));
    });

    test('tools/call without a name returns invalid-params error', () async {
      final d = buildDispatcher();
      final res = await d.handle(McpRequest(
        method: 'tools/call',
        id: 7,
        params: <String, dynamic>{'arguments': <String, dynamic>{}},
      ));
      expect(res.result, isNull);
      expect(res.error!.code, McpError.invalidParams.code);
    });

    test('custom tools list overrides the default', () async {
      final d = McpDispatcher(
        serverInfo: const McpServerInfo(name: 'n', version: 'v'),
        handlers: const {},
        tools: const [
          McpTool(
            name: 'only_tool',
            description: 'd',
            inputSchema: {'type': 'object'},
          ),
        ],
      );
      final res = await d.handle(McpRequest(method: 'tools/list', id: 8));
      final tools = (res.result as Map<String, dynamic>)['tools'] as List;
      expect(tools.length, 1);
      expect((tools.first as Map)['name'], 'only_tool');
    });
  });

  group('JSON shapes', () {
    test('McpRequest.fromJson parses method, params, id', () {
      final req = McpRequest.fromJson({
        'jsonrpc': '2.0',
        'method': 'tools/call',
        'id': 42,
        'params': {
          'name': 'echo',
          'arguments': {'x': 1},
        },
      });
      expect(req.method, 'tools/call');
      expect(req.id, 42);
      expect(req.params!['name'], 'echo');
    });

    test('McpRequest.toJson omits null params/id', () {
      final json = McpRequest(method: 'ping').toJson();
      expect(json['jsonrpc'], '2.0');
      expect(json['method'], 'ping');
      expect(json.containsKey('params'), isFalse);
      expect(json.containsKey('id'), isFalse);
    });

    test('McpResponse.success.toJson carries result, no error', () {
      final json =
          McpResponse.success(id: 1, result: {'ok': true}).toJson();
      expect(json['jsonrpc'], '2.0');
      expect(json['id'], 1);
      expect(json['result'], {'ok': true});
      expect(json.containsKey('error'), isFalse);
    });

    test('McpResponse.failure.toJson carries error, no result', () {
      final json = McpResponse.failure(
        id: 2,
        error: const McpError(code: -32602, message: 'bad'),
      ).toJson();
      expect(json.containsKey('result'), isFalse);
      final err = json['error'] as Map<String, dynamic>;
      expect(err['code'], -32602);
      expect(err['message'], 'bad');
    });

    test('McpError.toJson includes data only when present', () {
      const noData = McpError(code: 1, message: 'm');
      expect(noData.toJson().containsKey('data'), isFalse);

      final withData = const McpError(code: 1, message: 'm').withData('extra');
      expect(withData.toJson()['data'], 'extra');
    });

    test('McpToolResult.text builds a non-error text content block', () {
      final json = McpToolResult.text('hello').toJson();
      expect(json.containsKey('isError'), isFalse);
      final block = (json['content'] as List).first as Map<String, dynamic>;
      expect(block['type'], 'text');
      expect(block['text'], 'hello');
    });

    test('McpToolResult.errorText sets isError', () {
      final result = McpToolResult.errorText('nope');
      expect(result.isError, isTrue);
      expect(result.toJson()['isError'], isTrue);
      expect(result.content.first['text'], 'nope');
    });

    test('McpServerInfo.toJson advertises tools capability', () {
      final json =
          const McpServerInfo(name: 'a', version: 'b').toJson();
      expect(json['protocolVersion'], '2024-11-05');
      expect((json['serverInfo'] as Map)['name'], 'a');
      expect((json['capabilities'] as Map).containsKey('tools'), isTrue);
    });
  });
}
