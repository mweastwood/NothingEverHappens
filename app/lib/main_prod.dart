import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options_prod.dart';
import 'main.dart';
import 'logic/hive_local_data_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    }
  } catch (e, st) {
    // ignore: avoid_print
    print('⚠️ [PROD_FIREBASE_INIT_WARNING] Firebase init failed: $e\n$st');
  }

  AppConfig.environment = AppEnvironment.prod;

  final hiveDataSource = HiveLocalDataSource();
  try {
    await hiveDataSource.init();
  } catch (e, st) {
    // ignore: avoid_print
    print('⚠️ [PROD_HIVE_INIT_WARNING] Hive init failed: $e\n$st');
  }

  mainCommon(hiveDataSource);
}
