import 'package:flutter/material.dart';

import '../theme/clinical_theme.dart';
import '../l10n/app_strings.dart';

class AppPreferencesScreen extends StatelessWidget {
  const AppPreferencesScreen({super.key});

  static const _languages = <String, String>{
    'en': 'English',
    'si': 'සිංහල (Sinhala)',
    'ta': 'தமிழ் (Tamil)',
  };

  Future<void> _chooseLanguage(
    BuildContext context,
    ThemeManager preferences,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('choose_language'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ..._languages.entries.map(
                (language) => RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: language.key,
                  groupValue: preferences.languageCode,
                  title: Text(language.value),
                  onChanged: (value) => Navigator.pop(sheetContext, value),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      await preferences.setLanguage(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        final preferences = ThemeManager.instance;
        final scale = preferences.textScale;
        return Scaffold(
          appBar: AppBar(title: Text(context.tr('app_preferences'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('text_size'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('text_size_help'),
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                      Slider(
                        value: scale,
                        min: 0.9,
                        max: 1.4,
                        divisions: 5,
                        label: '${(scale * 100).round()}%',
                        onChanged: preferences.setTextScale,
                      ),
                      Center(
                        child: Text(
                          'Sample text at ${(scale * 100).round()}%',
                          style: TextStyle(fontSize: 16 * scale),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(context.tr('language')),
                  subtitle: Text(_languages[preferences.languageCode]!),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _chooseLanguage(context, preferences),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: Text(context.tr('reset_text_size')),
                  subtitle: Text(context.tr('reset_text_size_help')),
                  onTap: () async {
                    await preferences.setTextScale(1.0);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
