import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show
        Widget,
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

/// Apple 液态玻璃的四档强度（对齐 Origo X 的 Lite / Plus / Pro / Max）。
enum LiquidGlassLevel {
  lite,
  plus,
  pro,
  max;

  /// 档位副标题（与 Origo X 的展示一致）。
  String get description => switch (this) {
    LiquidGlassLevel.lite => '基本模糊',
    LiquidGlassLevel.plus => '适度模糊与适度反光',
    LiquidGlassLevel.pro => '柔和折射与均衡视觉',
    LiquidGlassLevel.max => '清晰折射与增强色彩',
  };
}

/// 是否在当前平台启用液态玻璃：仅 iOS，且不看系统版本。
///
/// liquidum 是纯 Flutter shader，iOS 15+ 开启 Impeller 即可渲染；
/// 低于 iOS 26 会降级为毛玻璃观感，但仍是玻璃材质，不会退回 Material。
bool get isIOSPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

LiquidGlassLevel liquidGlassLevelFromName(String? name) =>
    LiquidGlassLevel.values.firstWhere(
      (level) => level.name == name,
      orElse: () => LiquidGlassLevel.pro,
    );

/// 玻璃效果总开关（对应 Origo X 的「玻璃效果」）。
class LiquidGlassEnabledNotifier extends Notifier<bool> {
  static const _key = 'liquid_glass_enabled';

  @override
  bool build() => SharedPrefsService.instance.getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await SharedPrefsService.instance.setBool(_key, value);
  }
}

final liquidGlassEnabledProvider =
    NotifierProvider<LiquidGlassEnabledNotifier, bool>(
      LiquidGlassEnabledNotifier.new,
    );

/// 玻璃样式档位（对应 Origo X 的「玻璃样式」）。
class LiquidGlassLevelNotifier extends Notifier<LiquidGlassLevel> {
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
    NotifierProvider<LiquidGlassLevelNotifier, LiquidGlassLevel>(
      LiquidGlassLevelNotifier.new,
    );

/// 顶栏玻璃开关（对应 Origo X 的「顶栏玻璃」）：控制底部导航是否玻璃化。
class LiquidGlassNavNotifier extends Notifier<bool> {
  static const _key = 'liquid_glass_nav';

  @override
  bool build() => SharedPrefsService.instance.getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await SharedPrefsService.instance.setBool(_key, value);
  }
}

final liquidGlassNavProvider =
    NotifierProvider<LiquidGlassNavNotifier, bool>(LiquidGlassNavNotifier.new);

/// 渐进模糊开关（对应 Origo X 的「渐进模糊」）：开启时高档位使用 clear 玻璃
/// 以呈现更强的折射层次，关闭时统一用 regular 玻璃。
class LiquidGlassProgressiveNotifier extends Notifier<bool> {
  static const _key = 'liquid_glass_progressive';

  @override
  bool build() => SharedPrefsService.instance.getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await SharedPrefsService.instance.setBool(_key, value);
  }
}

final liquidGlassProgressiveProvider =
    NotifierProvider<LiquidGlassProgressiveNotifier, bool>(
      LiquidGlassProgressiveNotifier.new,
    );

/// widget build 期间调用：玻璃总开关是否生效（含平台判断）。
bool glassEnabled(WidgetRef ref) {
  if (!isIOSPlatform) return false;
  return ref.watch(liquidGlassEnabledProvider);
}

/// widget build 期间调用：当前档位（含平台判断）。
LiquidGlassLevel glassLevel(WidgetRef ref) {
  if (!isIOSPlatform) return LiquidGlassLevel.lite;
  return ref.watch(liquidGlassLevelProvider);
}

/// 档位 -> 玻璃半径倍率。
double _radiusFactor(LiquidGlassLevel level) => switch (level) {
  LiquidGlassLevel.lite => 0.7,
  LiquidGlassLevel.plus => 0.85,
  LiquidGlassLevel.pro => 1.0,
  LiquidGlassLevel.max => 1.15,
};

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
    if (!glassEnabled(ref)) return fallback(child);

    final level = glassLevel(ref);
    final progressive = ref.watch(liquidGlassProgressiveProvider);
    final style =
        progressive && level == LiquidGlassLevel.max
            ? GlassStyle.clear
            : GlassStyle.regular;

    return Glass(
      radius: radius * _radiusFactor(level),
      style: style,
      interactive: interactive || level == LiquidGlassLevel.max,
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
    if (!glassEnabled(ref)) {
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
    if (!glassEnabled(ref)) {
      return material.Switch(value: value, onChanged: onChanged);
    }
    return GlassSwitch(value: value, onChanged: onChanged ?? (_) {});
  }
}
