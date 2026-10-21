import 'package:flutter/material.dart';

import '../models/change_detail.dart';
import '../theme/app_colors.dart';

/// Renders the breakdown of a change: the key facts of the affected record and
/// the field level differences (`old -> new`, with the delta when it applies).
///
/// Used by the notification list, the audit log detail and the recent activity
/// feed so the admin always reads the same wording everywhere.
class ChangeDetailsView extends StatelessWidget {
  const ChangeDetailsView({
    super.key,
    this.changes = const [],
    this.facts = const [],
    this.itemLines = const [],
    this.dense = false,
  });

  final List<ChangeDetail> changes;
  final List<ChangeFact> facts;
  final List<String> itemLines;

  /// Compact mode drops the section headers and paddings - used inline.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (facts.isEmpty && changes.isEmpty && itemLines.isEmpty) {
      return const SizedBox.shrink();
    }

    final gap = dense ? 6.0 : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (facts.isNotEmpty) ...[
          if (!dense) _SectionLabel(text: 'Record details', icon: Icons.info_outline_rounded),
          ...facts.map((f) => _FactRow(fact: f, dense: dense)),
          SizedBox(height: gap),
        ],
        if (changes.isNotEmpty) ...[
          if (!dense) _SectionLabel(text: 'What changed', icon: Icons.compare_arrows_rounded),
          ...changes.map((c) => _ChangeRow(change: c, dense: dense)),
          SizedBox(height: gap),
        ],
        if (itemLines.isNotEmpty) ...[
          if (!dense) _SectionLabel(text: 'Items', icon: Icons.list_alt_rounded),
          ...itemLines.map(
            (line) => Padding(
              padding: EdgeInsets.only(bottom: dense ? 2 : 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: dense ? 11.5 : 12.5,
                        height: 1.35,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.secondary),
          const SizedBox(width: 5),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact, required this.dense});

  final ChangeFact fact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 2 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: dense ? 96 : 116,
            child: Text(
              fact.label,
              style: TextStyle(
                fontSize: dense ? 11 : 12,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              fact.value,
              style: TextStyle(
                fontSize: dense ? 11.5 : 12.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change, required this.dense});

  final ChangeDetail change;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color;

    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 3 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            change.label,
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(height: 2),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                change.from,
                style: TextStyle(
                  fontSize: dense ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger.withValues(alpha: 0.9),
                  decoration: change.from.isEmpty ? null : TextDecoration.lineThrough,
                  decorationColor: AppColors.danger.withValues(alpha: 0.5),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: dense ? 12 : 14, color: muted),
              Text(
                change.to,
                style: TextStyle(
                  fontSize: dense ? 11.5 : 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
              if (change.hasDelta)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    change.delta,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.info,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
