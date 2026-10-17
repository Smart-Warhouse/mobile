import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/providers.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../auth/presentation/providers/session_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider);
    final locale = ref.watch(localeProvider);
    final t = context.sw;
    final signedIn = session is SignedIn ? session : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Sp.lg),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.hardDrives),
                  title: Text(l10n.settingsServer),
                  subtitle: Text(
                    signedIn?.baseUrl ?? '',
                    textDirection: TextDirection.ltr,
                  ),
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.user),
                  title: Text(l10n.settingsUser),
                  subtitle: Text(
                    signedIn == null
                        ? ''
                        : '${signedIn.user.name} (${signedIn.user.username})',
                  ),
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.identificationBadge),
                  title: Text(l10n.settingsRole),
                  subtitle: Text(
                    signedIn == null ? '' : l10n.role(signedIn.user.role),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.lg),
          Text(
            l10n.settingsLanguage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Sp.sm),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'ar', label: Text(l10n.langArabic)),
              ButtonSegment(value: 'en', label: Text(l10n.langEnglish)),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (s) =>
                ref.read(localeProvider.notifier).set(Locale(s.first)),
          ),
          const SizedBox(height: Sp.xl),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: t.danger),
            icon: const Icon(PhosphorIconsRegular.signOut),
            label: Text(l10n.signOut),
            onPressed: () async {
              final ok = await confirmAction(
                context,
                title: l10n.signOutConfirm,
                confirmLabel: l10n.signOut,
              );
              if (ok) {
                await ref.read(sessionControllerProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
    );
  }
}
