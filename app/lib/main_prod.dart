import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options_prod.dart';
import 'main.dart';
import 'logic/hive_local_data_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Enable persistence for Web
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  AppConfig.environment = AppEnvironment.prod;

  final hiveDataSource = HiveLocalDataSource();
  await hiveDataSource.init();

  mainCommon(hiveDataSource);
}
