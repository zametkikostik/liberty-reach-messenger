import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/translation_service.dart';
import '../services/theme_service.dart';

/// 🌐 Translate Button Widget
///
/// Shows translate option in message context menu
class TranslateButton extends StatelessWidget {
  final String text;
  final String targetLanguage;
  final Function(String translatedText) onTranslated;

  const TranslateButton({
    super.key,
    required this.text,
    required this.targetLanguage,
    required this.onTranslated,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;
    final translationService = TranslationService.instance;

    return GestureDetector(
      onTap: () async {
        // Show loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Translating...'),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );

        // Translate
        final translated = await translationService.autoTranslate(
          text: text,
          targetLanguage: targetLanguage,
        );

        // Show result
        onTranslated(translated);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Translated to $targetLanguage'),
              backgroundColor: colors[0],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.translate,
              color: colors[0],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Translate to $targetLanguage',
              style: GoogleFonts.firaCode(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🌐 Language Selector Dialog
class LanguageSelector extends StatelessWidget {
  final Function(String language) onLanguageSelected;

  const LanguageSelector({
    super.key,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Container(
      decoration: BoxDecoration(
        color: themeService.isGhostMode
            ? const Color(0xFF1A1A2E)
            : const Color(0xFF2E1A2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.translate, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Select Language',
                  style: GoogleFonts.firaCode(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Language list
          SizedBox(
            height: 300,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: Language.common.length,
              itemBuilder: (context, index) {
                final lang = Language.common[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors[0].withOpacity(0.2),
                    child: Text(
                      lang.code.toUpperCase(),
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        color: colors[0],
                      ),
                    ),
                  ),
                  title: Text(
                    lang.name,
                    style: GoogleFonts.firaCode(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    lang.nativeName,
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  onTap: () {
                    onLanguageSelected(lang.name);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
