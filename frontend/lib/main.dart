import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/router.dart';
import 'core/services/offline_queue_service.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show detailed error messages instead of blank screens
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            SelectableText(
              '${details.exception}',
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  };

  await ApiClient.restoreTenantSchema();
  await OfflineQueueService.instance.load();
  runApp(const ProviderScope(child: AdhereMedApp()));
}

class AdhereMedApp extends ConsumerWidget {
  const AdhereMedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: 'AdhereMed',
      theme: AppTheme.buildTheme(themeMode),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
