import 'package:flutter_hbb/common.dart';

class KVMServerModel {
  final String name;
  final ServerConfig config;
  final String baseUrl;

  /// Switches between `https` (true) and `http` (false) when resolving the
  /// [baseUrl]. Ignored when [baseUrlResolutionOverride] is set.
  bool useHttps;

  /// When set to a non-empty value, this is used verbatim as the resolved
  /// base url, ignoring both [useHttps] and [baseUrl].
  String? baseUrlResolutionOverride;

  KVMServerModel({
    required this.name,
    required this.config,
    required this.baseUrl,
    this.useHttps = true,
    this.baseUrlResolutionOverride,
  });

  /// The base url that should be used for API requests.
  ///
  /// If [baseUrlResolutionOverride] is set, it takes precedence. Otherwise the
  /// [baseUrl] host is resolved using the scheme selected by [useHttps].
  String get resolvedBaseUrl {
    final override = baseUrlResolutionOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    final scheme = useHttps ? 'https' : 'http';
    // Strip any scheme already present in baseUrl to avoid double schemes.
    final host = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    return '$scheme://$host';
  }
}
