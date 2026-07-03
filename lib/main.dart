import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'root_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MediConnectDoctorApp());
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
        home: const RootShell(),
      ),
    );
  }
}
