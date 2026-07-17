import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'root_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  // Catches anything that slips past a local try/catch (e.g. an unexpected
  // backend JSON shape hitting an unguarded cast) so it's logged instead of
  // taking down the whole app with a blank/crashed screen.
  runZonedGuarded(() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Uncaught Flutter error: ${details.exceptionAsString()}');
    };
    runApp(const MediConnectDoctorApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

class MediConnectDoctorApp extends StatelessWidget {
  const MediConnectDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'MediConnectAI – Doctor App',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // Keeps the doctor-facing layout (designed/tested around phone
        // widths) from stretching into oversized, awkwardly-spaced content
        // on tablets/large phones, without hardcoding a max width per screen.
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return Container(
            color: AppColors.blue50,
            alignment: Alignment.topCenter,
            child: MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: mediaQuery.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: child,
              ),
            ),
          );
        },
        home: const RootShell(),
      ),
    );
  }
}
