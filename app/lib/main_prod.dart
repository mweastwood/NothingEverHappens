import 'package:firebase_core/firebase_core.dart';
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
  } catch (e) {
    debugPrint('Prod Firebase init error: $e');
  }

  AppConfig.environment = AppEnvironment.prod;

  final hiveDataSource = HiveLocalDataSource();
  try {
    await hiveDataSource.init();
  } catch (e) {
    debugPrint('Prod Hive init error: $e');
  }

  mainCommon(hiveDataSource);
}
