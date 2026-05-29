/// Type definitions for the Planom Model Context Protocol (MCP) integration.
///
/// MCP is a JSON-RPC 2.0 based protocol developed by Anthropic that lets AI
/// models talk to external tools and data sources via a uniform interface.
/// See https://modelcontextprotocol.io for the spec.
///
/// This file only defines the wire-format types. The dispatcher lives in
/// `mcp_dispatcher.dart` and the controller wiring lives in `mcp_server.dart`.
library;

/// JSON-RPC 2.0 request envelope.
class McpRequest {
  McpRequest({
    required this.method,
    this.params,
    this.id,
  });

  /// Tool / endpoint name (e.g. `tools/list`, `tools/call`).
  final String method;

  /// Method-specific arguments (typically `{name, arguments}` for `tools/call`).
  final Map<String, dynamic>? params;

  /// Request id — echoed back in the response. Null = notification (no reply).
  final dynamic id;

  factory McpRequest.fromJson(Map<String, dynamic> json) => McpRequest(
        method: json['method'] as String,
        params: json['params'] as Map<String, dynamic>?,
        id: json['id'],
      );

  Map<String, dynamic> toJson() => {
        'jsonrpc': '2.0',
        'method': method,
        if (params != null) 'params': params,
        if (id != null) 'id': id,
      };
}

/// JSON-RPC 2.0 response envelope. Exactly one of [result] / [error] is set.
class McpResponse {
  McpResponse._({this.id, this.result, this.error});

  factory McpResponse.success({dynamic id, required dynamic result}) =>
      McpResponse._(id: id, result: result);

  factory McpResponse.failure({dynamic id, required McpError error}) =>
      McpResponse._(id: id, error: error);

  final dynamic id;
  final dynamic result;
  final McpError? error;

  Map<String, dynamic> toJson() => {
        'jsonrpc': '2.0',
        if (id != null) 'id': id,
        if (error != null) 'error': error!.toJson() else 'result': result,
      };
}

/// Standard JSON-RPC error envelope. The numeric [code] follows the JSON-RPC
/// 2.0 conventions: -32700 parse error, -32600 invalid request, -32601 method
/// not found, -32602 invalid params, -32603 internal error, plus app-specific
/// codes above -32000.
class McpError {
  const McpError({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final Object? data;

  static const McpError methodNotFound =
      McpError(code: -32601, message: 'Method not found');
  static const McpError invalidParams =
      McpError(code: -32602, message: 'Invalid params');
  static const McpError internalError =
      McpError(code: -32603, message: 'Internal error');

  McpError withData(Object data) =>
      McpError(code: code, message: message, data: data);

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };
}

/// Describes a single MCP tool the model can invoke. The `inputSchema` is a
/// JSON Schema object that describes the tool's arguments.
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// Result of a successful `tools/call` invocation. Follows the MCP content
/// block shape: `[{type: 'text', text: '...'}]`.
class McpToolResult {
  McpToolResult.text(String text)
      : content = [
          {'type': 'text', 'text': text}
        ],
        isError = false;

  McpToolResult.errorText(String text)
      : content = [
          {'type': 'text', 'text': text}
        ],
        isError = true;

  final List<Map<String, dynamic>> content;
  final bool isError;

  Map<String, dynamic> toJson() => {
        'content': content,
        if (isError) 'isError': true,
      };
}

/// Server description returned by the `initialize` handshake. The model uses
/// this to decide which tools are available and what protocol version to use.
class McpServerInfo {
  const McpServerInfo({
    required this.name,
    required this.version,
    this.protocolVersion = '2024-11-05',
  });

  final String name;
  final String version;
  final String protocolVersion;

  Map<String, dynamic> toJson() => {
        'protocolVersion': protocolVersion,
        'serverInfo': {'name': name, 'version': version},
        'capabilities': const {
          'tools': {},
        },
      };
}
