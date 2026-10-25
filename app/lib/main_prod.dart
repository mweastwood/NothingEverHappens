import 'firebase_options_prod.dart';
import 'main.dart';

Future<void> main() async {
  await bootstrapApp(
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    environment: AppEnvironment.prod,
  );
}
