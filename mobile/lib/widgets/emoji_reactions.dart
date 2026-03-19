import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/emoji_reactions_service.dart';
import '../services/theme_service.dart';

/// 👍 Reaction Picker Widget
///
/// Shows emoji picker for adding reactions to messages
class ReactionPicker extends StatelessWidget {
  final Function(String reaction) onReactionSelected;

  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: themeService.isGhostMode
            ? const Color(0xFF1A1A2E)
            : const Color(0xFF2E1A2E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: EmojiReactionsService.defaultReactions.map((emoji) {
          return GestureDetector(
            onTap: () {
              onReactionSelected(emoji);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 👍 Reaction Display Widget
///
/// Shows reactions below a message
class ReactionDisplay extends StatelessWidget {
  final Map<String, Map<String, dynamic>> reactions;
  final String currentUserId;
  final Function(String reactionType) onReactionTap;

  const ReactionDisplay({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: reactions.entries.map((entry) {
        final emoji = entry.key;
        final data = entry.value;
        final count = data['count'] as int;
        final users = data['users'] as List;
        final hasUserReacted = users.contains(currentUserId);

        return GestureDetector(
          onTap: () => onReactionTap(emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasUserReacted
                  ? Theme.of(context).primaryColor.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasUserReacted
                    ? Theme.of(context).primaryColor
                    : Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: hasUserReacted
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 👍 Reaction Button Widget
///
/// Long-press button to show reaction picker
class ReactionButton extends StatefulWidget {
  final String messageId;
  final String currentUserId;
  final Function(String reaction) onReactionAdded;

  const ReactionButton({
    super.key,
    required this.messageId,
    required this.currentUserId,
    required this.onReactionAdded,
  });

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton> {
  bool _showPicker = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showPicker = !_showPicker);
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.add_reaction_outlined,
          size: 16,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }
}
