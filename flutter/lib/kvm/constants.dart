import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_server_config.dart';

const defaultHeartbeatS = 60;

const String? prefilledEmail = null;
const String? prefilledPass = null;

//Rustdesk relay server
const String? idServer = null;
const String? relayServer = null;
const String? apiServer = null;
const String? key = null;

final List<KVMServerModel> kvmServers = [
  KVMServerModel(
    name: "dexmanager",
    config:  ServerConfig(
      idServer: dotenv.env['DEXMANAGER_SV_S'],
      relayServer: dotenv.env['DEXMANAGER_SV_R'],
      key: dotenv.env['DEXMANAGER_SV_KEY'],
    ),
    baseUrl: dotenv.env['DEXMANAGER_BASE_URL'] ?? '',
  ),
  KVMServerModel(
    name: "jmbajo",
    config:  ServerConfig(
      idServer: dotenv.env['JMBAJO_SV_S'],
      relayServer: dotenv.env['JMBAJO_SV_R'],
      key: dotenv.env['JMBAJO_SV_KEY'],
    ),
    baseUrl: dotenv.env['JMBAJO_BASE_URL'] ?? '',
  ),
];

const int buildNumber = 10;
const String buildDate = "26/10/2026";

