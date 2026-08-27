import 'package:flutter_hbb/common.dart';

class KVMServerModel {
  final String name;
  final ServerConfig config;
  final String baseUrl;

  KVMServerModel({
    required this.name,
    required this.config,
    required this.baseUrl,
  });
}
