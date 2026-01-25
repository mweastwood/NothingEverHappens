import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'screens/task_list_screen.dart';

void mainCommon() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightScheme = lightDynamic;
          darkScheme = darkDynamic;
        } else {
          lightScheme = ColorScheme.fromSeed(
            seedColor: Colors.white,
            dynamicSchemeVariant: DynamicSchemeVariant.neutral,
          );
          darkScheme = ColorScheme.fromSeed(
            seedColor: Colors.white,
            brightness: Brightness.dark,
            dynamicSchemeVariant: DynamicSchemeVariant.neutral,
          );
        }

        return MaterialApp(
          title: 'Nothing Ever Happens',
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: const TaskListScreen(),
        );
      },
    );
  }
}
