import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show
        Widget,
        StatelessWidget,
        BuildContext,
        Key,
        ValueChanged,
        VoidCallback,
        IconData,
        Row,
        MainAxisSize;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquidum/liquidum.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:material_ui/material_ui.dart' as material;

/// Apple 液态玻璃的四档强度（命名借鉴 iPhone 产品线）。
///
/// 用户可在设置中切换；默认 Pro Max（较强的玻璃观感）。
enum LiquidGlassLevel {
  off,
  plus,
  proMax,
  ultra;

  String get storageKey => 'liquid_glass_level';
}

/// 是否应在当前平台启用液态玻璃。
///
/// 只在 iOS 上启用，且不看系统版本：liquidum 是纯 Flutter shader，
/// iOS 15+ 开启 Impeller 即可渲染；低于 iOS 26 会降级为毛玻璃观感，
/// 但仍保持玻璃材质，不会退回 Material 风格。
bool get isIOSPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// 从枚举名恢复档位（兼容旧值），未知值回退到 Pro Max。
LiquidGlassLevel liquidGlassLevelFromName(String? name) =>
    LiquidGlassLevel.values.firstWhere(
      (level) => level.name == name,
      orElse: () => LiquidGlassLevel.proMax,
    );

/// 毛玻璃档位状态：独立 provider，不侵入 AppSettings（避免改动扩散）。
class LiquidGlassNotifier extends Notifier<LiquidGlassLevel> {
  static const _key = 'liquid_glass_level';

  @override
  LiquidGlassLevel build() => liquidGlassLevelFromName(
    SharedPrefsService.instance.getString(_key),
  );

  Future<void> set(LiquidGlassLevel level) async {
    state = level;
    await SharedPrefsService.instance.setString(_key, level.name);
  }
}

final liquidGlassLevelProvider =
    NotifierProvider<LiquidGlassNotifier, LiquidGlassLevel>(
      LiquidGlassNotifier.new,
    );

/// 在 widget build 期间调用：当前生效档位。非 iOS 恒为 off。
LiquidGlassLevel effectiveGlassLevel(WidgetRef ref) {
  if (!isIOSPlatform) return LiquidGlassLevel.off;
  return ref.watch(liquidGlassLevelProvider);
}

bool _isOn(LiquidGlassLevel level) => level != LiquidGlassLevel.off;

/// 平台感知、档位感知的圆角矩形玻璃面。
class AdaptiveGlassPanel extends ConsumerWidget {
  const AdaptiveGlassPanel({
    super.key,
    required this.child,
    required this.fallback,
    this.radius = 20,
    this.interactive = false,
  });

  final Widget child;
  final Widget Function(Widget child) fallback;
  final double radius;
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = effectiveGlassLevel(ref);
    if (!_isOn(level)) return fallback(child);

    // 三档玻璃的强度差异：半径递增 + Ultra 使用 clear 玻璃（更通透）。
    final effectiveRadius = switch (level) {
      LiquidGlassLevel.plus => radius * 0.8,
      LiquidGlassLevel.proMax => radius,
      LiquidGlassLevel.ultra => radius * 1.2,
      LiquidGlassLevel.off => radius,
    };
    final effectiveInteractive = interactive || level == LiquidGlassLevel.ultra;
    final style = level == LiquidGlassLevel.ultra
        ? GlassStyle.clear
        : GlassStyle.regular;

    return Glass(
      radius: effectiveRadius,
      style: style,
      interactive: effectiveInteractive,
      child: child,
    );
  }
}

/// 平台感知、档位感知的主按钮。
class AdaptiveGlassButton extends ConsumerWidget {
  const AdaptiveGlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.prominent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool prominent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = effectiveGlassLevel(ref);
    if (!_isOn(level)) {
      final content = icon == null
          ? material.Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                material.Icon(icon, size: 18),
                const material.SizedBox(width: 8),
                material.Text(label),
              ],
            );
      return material.FilledButton(onPressed: onPressed, child: content);
    }

    return GlassButton(
      label: label,
      prominent: prominent,
      onPressed: onPressed ?? () {},
    );
  }
}

/// 平台感知、档位感知的开关。
class AdaptiveGlassSwitch extends ConsumerWidget {
  const AdaptiveGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = effectiveGlassLevel(ref);
    if (!_isOn(level)) {
      return material.Switch(value: value, onChanged: onChanged);
    }
    return GlassSwitch(value: value, onChanged: onChanged ?? (_) {});
  }
}
