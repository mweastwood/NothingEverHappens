import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options_dev.dart';
import 'main.dart';
import 'logic/hive_local_data_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  AppConfig.environment = AppEnvironment.dev;

  final hiveDataSource = HiveLocalDataSource();
  await hiveDataSource.init();

  mainCommon(hiveDataSource);
}
