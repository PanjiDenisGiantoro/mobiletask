import 'package:flutter/material.dart';
import '../../stitch_frontend_interface_application/app_theme.dart';
import '../ph_format.dart';
import '../ph_store.dart';

const phCardShadow = [BoxShadow(color: Color(0x14212121), blurRadius: 12, offset: Offset(0, 4))];

/// AppBar bergradien biru-teal yang sama dengan layar Tasks/Projects.
AppBar phAppBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom, bool solid = false}) {
  return AppBar(
    backgroundColor: AppColors.heroStart,
    foregroundColor: Colors.white,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: solid
            ? null
            : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.heroStart, AppColors.heroMid]),
      ),
    ),
    title: Text(title),
    actions: actions,
    bottom: bottom,
  );
}

PreferredSizeWidget phTabBar(TabController c, List<String> tabs) => TabBar(
      controller: c,
      indicatorColor: Colors.white,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      tabs: [for (final t in tabs) Tab(text: t)],
    );

void phToast(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message)));
}

class PhPill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const PhPill(this.label, {super.key, required this.fg, required this.bg});

  factory PhPill.status(String group, String statusKey) {
    final s = statusStyle(group, statusKey);
    return PhPill(s.label, fg: s.fg, bg: s.bg);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );
}

class PhCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const PhCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.md), this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.large), boxShadow: phCardShadow),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

class PhSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const PhSection(this.title, {super.key, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title.toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey500, letterSpacing: 0.8)),
                  ),
                  ?trailing,
                ],
              ),
            ),
            child,
          ],
        ),
      );
}

/// Kartu pasangan label-nilai, dipakai di semua layar detail.
class KvCard extends StatelessWidget {
  final List<(String, Object?)> rows;
  const KvCard(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    final items = rows.where((r) => r.$2 != null).toList();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.large), boxShadow: phCardShadow),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.grey100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 118, child: Text(items[i].$1, style: const TextStyle(fontSize: 13, color: AppColors.grey700))),
                  Expanded(
                    child: items[i].$2 is Widget
                        ? Align(alignment: Alignment.centerLeft, child: items[i].$2 as Widget)
                        : Text(
                            (items[i].$2 as String).isEmpty ? '-' : items[i].$2 as String,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.grey900),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PhAvatar extends StatelessWidget {
  final String userId;
  final double size;
  const PhAvatar(this.userId, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.primary50, shape: BoxShape.circle),
        child: Text(initials(PhStore.instance.nameOf(userId)),
            style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: AppColors.primary700)),
      );
}

/// Baris daftar dengan judul, keterangan, dan pil status di kanan.
class PhListRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final String? trailingNote;
  final Widget? leading;
  final VoidCallback? onTap;
  const PhListRow({super.key, required this.title, this.subtitle = '', this.trailing, this.trailingNote, this.leading, this.onTap});

  @override
  Widget build(BuildContext context) => PhCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grey900)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.grey700, height: 1.3)),
                  ],
                ],
              ),
            ),
            if (trailing != null || trailingNote != null) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ?trailing,
                  if (trailingNote != null) ...[
                    const SizedBox(height: 4),
                    Text(trailingNote!, style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
}

class PhEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const PhEmpty(this.icon, this.text, {super.key, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.grey400),
              const SizedBox(height: AppSpacing.sm),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey700, fontSize: 14)),
              if (action != null) ...[const SizedBox(height: AppSpacing.md), action!],
            ],
          ),
        ),
      );
}

/// Baris chip filter horizontal (latar putih) di bawah AppBar.
class PhChipBar extends StatelessWidget {
  final List<(String, String)> items;
  final String selected;
  final ValueChanged<String> onSelected;
  const PhChipBar({super.key, required this.items, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.white,
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, i) {
            final on = items[i].$1 == selected;
            return GestureDetector(
              onTap: () => onSelected(items[i].$1),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(color: on ? AppColors.heroStart : AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Text(items[i].$2,
                    style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? Colors.white : AppColors.grey700)),
              ),
            );
          },
        ),
      );
}

class PhButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? fg;
  final bool compact;
  const PhButton(this.label, {super.key, this.onPressed, this.icon, this.color, this.fg, this.compact = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: compact ? null : double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18, color: fg ?? Colors.white),
          label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: fg ?? Colors.white)),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: color ?? AppColors.primary700,
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14, horizontal: compact ? 16 : 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
          ),
        ),
      );
}

PhButton phGreenButton(String label, VoidCallback onPressed, {IconData? icon}) =>
    PhButton(label, onPressed: onPressed, icon: icon, color: AppColors.successBg, fg: const Color(0xFF2E7D32));
PhButton phRedButton(String label, VoidCallback onPressed, {IconData? icon}) =>
    PhButton(label, onPressed: onPressed, icon: icon, color: AppColors.errorBg, fg: const Color(0xFFC62828));
PhButton phSoftButton(String label, VoidCallback onPressed, {IconData? icon}) =>
    PhButton(label, onPressed: onPressed, icon: icon, color: AppColors.primary50, fg: AppColors.primary800);

Widget phGap([double h = AppSpacing.sm]) => SizedBox(height: h);

/// Kartu judul besar dengan pil di layar detail.
class PhHeaderCard extends StatelessWidget {
  final String title;
  final List<Widget> pills;
  final Widget? extra;
  const PhHeaderCard({super.key, required this.title, this.pills = const [], this.extra});

  @override
  Widget build(BuildContext context) => PhCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.grey900, height: 1.3)),
            if (pills.isNotEmpty) ...[const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: pills)],
            if (extra != null) ...[const SizedBox(height: 8), extra!],
          ],
        ),
      );
}

Future<bool> phConfirm(BuildContext context, {required String title, required String message, String confirm = 'Hapus'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(confirm, style: const TextStyle(color: AppColors.error))),
      ],
    ),
  );
  return r ?? false;
}

/// Membangun ulang widget saat [PhStore] berubah.
class PhStoreBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, PhStore store) builder;
  const PhStoreBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: PhStore.instance,
        builder: (c, _) => builder(c, PhStore.instance),
      );
}
