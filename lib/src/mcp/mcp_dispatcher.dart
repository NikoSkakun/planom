/// Routes incoming MCP JSON-RPC requests to the appropriate tool handler.
///
/// The dispatcher is transport-agnostic — call [handle] with a parsed request
/// and get a response back. A stdio or HTTP bridge can wrap it (see
/// `mcp_server.dart` for the wiring against Planom's controllers).
library;

import 'dart:async';

import 'mcp_tools.dart';
import 'mcp_types.dart';

/// Signature for a tool handler. Returns the textual result the model sees;
/// throw to surface an error as `isError: true`.
typedef McpToolHandler = FutureOr<String> Function(
    Map<String, dynamic> arguments);

/// Stateless JSON-RPC router. Holds a map of tool names to handlers and
/// implements the `initialize`, `tools/list`, and `tools/call` methods that
/// every MCP server is expected to support.
class McpDispatcher {
  McpDispatcher({
    required this.serverInfo,
    required Map<String, McpToolHandler> handlers,
    List<McpTool> tools = kPlanomMcpTools,
  })  : _handlers = handlers,
        _tools = tools;

  final McpServerInfo serverInfo;
  final Map<String, McpToolHandler> _handlers;
  final List<McpTool> _tools;

  Future<McpResponse> handle(McpRequest req) async {
    switch (req.method) {
      case 'initialize':
        return McpResponse.success(id: req.id, result: serverInfo.toJson());
      case 'tools/list':
        return McpResponse.success(
          id: req.id,
          result: {'tools': _tools.map((t) => t.toJson()).toList()},
        );
      case 'tools/call':
        return _handleToolCall(req);
      default:
        return McpResponse.failure(id: req.id, error: McpError.methodNotFound);
    }
  }

  Future<McpResponse> _handleToolCall(McpRequest req) async {
    final params = req.params ?? const <String, dynamic>{};
    final name = params['name'] as String?;
    if (name == null) {
      return McpResponse.failure(
        id: req.id,
        error: McpError.invalidParams.withData('Missing tool name'),
      );
    }
    final handler = _handlers[name];
    if (handler == null) {
      return McpResponse.failure(
        id: req.id,
        error: McpError.methodNotFound.withData('Unknown tool: $name'),
      );
    }
    final args = (params['arguments'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    try {
      final text = await handler(args);
      return McpResponse.success(id: req.id, result: McpToolResult.text(text));
    } catch (e, st) {
      return McpResponse.success(
        id: req.id,
        result: McpToolResult.errorText('$e\n$st'),
      );
    }
  }
}
