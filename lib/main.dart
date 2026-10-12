import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../providers/queue_provider.dart';
import 'screens/home_screen.dart';

final GlobalKey<ScaffoldMessengerState> globalSnackbarKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (e) {
    print("Main başlatma hatası: $e");
  }

  runApp(const HarmonyPlayerApp());
}

class HarmonyPlayerApp extends StatelessWidget {
  const HarmonyPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => QueueProvider()),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: globalSnackbarKey,
        title: 'Harmony Player',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF141416),
          primaryColor: const Color(0xFF8E24AA),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8E24AA),
            secondary: Color(0xFFFF9800),
            surface: Color(0xFF1E1E24),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF141416),
            elevation: 0,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
