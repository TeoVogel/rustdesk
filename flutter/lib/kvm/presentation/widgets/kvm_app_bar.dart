import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/kvm/domain/kvm_state_provider.dart';
import 'package:flutter_hbb/kvm/kvm_routing_utils.dart';
import 'package:provider/provider.dart';

SliverAppBar getKVMSliverAppBar(BuildContext context) => SliverAppBar.large(
      actions: [
        IconButton(
          onPressed: () {
            gFFI.serverModel.stopService();
            context.read<KVMStateProvider>().onUserSessionExpired();
          },
          icon: Icon(Icons.restart_alt_rounded),
        ),
        IconButton(
          onPressed: () {
            KVMRoutingUtils.goToRustDeskHomePage(context);
          },
          icon: Icon(Icons.open_in_new_rounded),
        ),
      ],
      flexibleSpace: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight,
          bottom: 16,
        ),
        child: Center(
            child: Image.asset(
          "assets/dex_logo.png",
          scale: 1,
        )),
      ),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24))),
    );
