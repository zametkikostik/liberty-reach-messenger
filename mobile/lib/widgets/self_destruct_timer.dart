import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/self_destruct_service.dart';
import '../services/theme_service.dart';

/// ⏱️ Self-Destruct Timer Selector
///
/// Bottom sheet for selecting message timer duration
class SelfDestructTimerSelector extends StatelessWidget {
  final String? currentTimer;
  final Function(String durationKey) onTimerSelected;

  const SelfDestructTimerSelector({
    super.key,
    this.currentTimer,
    required this.onTimerSelected,
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                const Icon(Icons.timer_off, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Self-Destruct Timer',
                  style: GoogleFonts.firaCode(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Messages will automatically delete after the selected time period.',
              style: GoogleFonts.firaCode(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),

          // Timer options
          ...SelfDestructService.timerPresets.entries.map((entry) {
            final key = entry.key;
            final duration = entry.value;
            final isSelected = currentTimer == key;

            return ListTile(
              leading: Icon(
                Icons.timer_outlined,
                color: isSelected ? colors[0] : Colors.white54,
              ),
              title: Text(
                SelfDestructService.getPresetLabel(key),
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  color: isSelected ? colors[0] : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
              subtitle: Text(
                'Auto-delete after ${duration.inMinutes} min',
                style: GoogleFonts.firaCode(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: colors[0],
                    )
                  : null,
              onTap: () {
                onTimerSelected(key);
                Navigator.pop(context);
              },
            );
          }),

          // Cancel timer option
          if (currentTimer != null)
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: Text(
                'Disable Timer',
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
              subtitle: const Text(
                'Message will not auto-delete',
                style: TextStyle(fontSize: 11, color: Colors.red),
              ),
              onTap: () {
                onTimerSelected('cancel');
                Navigator.pop(context);
              },
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// ⏱️ Timer Button for MessageInput
class TimerButton extends StatelessWidget {
  final String? currentTimer;
  final Function(String durationKey) onTimerSelected;

  const TimerButton({
    super.key,
    this.currentTimer,
    required this.onTimerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return IconButton(
      icon: Stack(
        children: [
          const Icon(Icons.timer_outlined, size: 28),
          if (currentTimer != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[0],
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      color: currentTimer != null ? colors[0] : Colors.white54,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => SelfDestructTimerSelector(
            currentTimer: currentTimer,
            onTimerSelected: onTimerSelected,
          ),
        );
      },
    );
  }
}
