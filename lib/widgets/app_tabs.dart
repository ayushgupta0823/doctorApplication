import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One tab bar component for the two tab visual languages that used to be
/// reimplemented per-screen (`_FilterTab` in Queue, `_TabChip` in Patient
/// Details, `_SubTab` in the Consult Room) — same look, same animation,
/// one place to change it.
enum AppTabStyle {
  /// Filled rounded-pill chips (used for filter-style tabs, e.g. Queue).
  pill,

  /// Underlined text tabs (used for section tabs, e.g. Patient Details,
  /// Consult Room).
  underline,
}

class AppTab {
  const AppTab({required this.label, required this.value});
  final String label;
  final Object value;
}

class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
    this.style = AppTabStyle.underline,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<AppTab> tabs;
  final Object selected;
  final ValueChanged<Object> onChanged;
  final AppTabStyle style;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: style == AppTabStyle.pill ? 36 : 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          for (final tab in tabs)
            _AppTabItem(
              label: tab.label,
              active: tab.value == selected,
              style: style,
              onTap: () => onChanged(tab.value),
            ),
        ],
      ),
    );
  }
}

class _AppTabItem extends StatelessWidget {
  const _AppTabItem({required this.label, required this.active, required this.style, required this.onTap});
  final String label;
  final bool active;
  final AppTabStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (style == AppTabStyle.pill) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: active ? AppColors.blue600 : AppColors.white,
          borderRadius: BorderRadius.circular(100),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: active ? AppColors.blue600 : AppColors.line),
                boxShadow: active ? AppShadow.sm : null,
              ),
              alignment: Alignment.center,
              child: Text(label, style: AppText.body(size: 11.5, weight: FontWeight.w700, color: active ? Colors.white : AppColors.ink600)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppColors.blue600 : Colors.transparent, width: 2))),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.body(size: 12.5, weight: FontWeight.w700, color: active ? AppColors.blue700 : AppColors.ink400),
          ),
        ),
      ),
    );
  }
}
