

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_server_config.dart';

final List<KVMServerModel> kvmServers = [
  KVMServerModel(
    name: "dexmanager",
    config:  ServerConfig(
      idServer: dotenv.env['DEXMANAGER_SV_S'],
      relayServer: dotenv.env['DEXMANAGER_SV_R'],
      key: dotenv.env['DEXMANAGER_SV_KEY'],
    ),
  ),
  KVMServerModel(
    name: "jmbajo",
    config:  ServerConfig(
      idServer: dotenv.env['JMBAJO_SV_S'],
      relayServer: dotenv.env['JMBAJO_SV_R'],
      key: dotenv.env['JMBAJO_SV_KEY'],
    ),
  ),
];