import 'firebase_options_dev.dart';
import 'main.dart';

Future<void> main() async {
  await bootstrapApp(
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    environment: AppEnvironment.dev,
  );
}
