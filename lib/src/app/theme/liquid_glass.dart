import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show Widget, StatelessWidget, BuildContext, Key, ValueChanged, VoidCallback, IconData;
import 'package:liquidum/liquidum.dart';
import 'package:material_ui/material_ui.dart' as material;

/// iOS 上全局强制启用 Apple 液态玻璃（不受系统版本限制）。
///
/// liquidum 基于 Flutter shader，只要 Impeller 开启（iOS 默认开启）即可渲染
/// 玻璃折射；系统低于 iOS 26 时自然降级为毛玻璃观感，但仍保持玻璃材质与
/// 交互，不会退回 Material 风格。桌面 / Android 保持原样。
bool get isLiquidGlass =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// 平台感知的圆角矩形玻璃面。
///
/// iOS：liquidum 玻璃；其它平台：交由 [fallback] 构建原 Material 组件，
/// 保证桌面 / Android 的观感与行为完全不变。
class AdaptiveGlassPanel extends StatelessWidget {
  const AdaptiveGlassPanel({
    super.key,
    required this.child,
    required this.fallback,
    this.radius = 20,
    this.interactive = false,
  });

  final Widget child;

  /// 非 iOS 平台使用的构建器，用于保留原 Material 组件。
  final Widget Function(Widget child) fallback;
  final double radius;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    if (!isLiquidGlass) return fallback(child);
    return Glass(radius: radius, interactive: interactive, child: child);
  }
}

/// 平台感知的主按钮。
///
/// iOS：liquidum 胶囊玻璃按钮；其它平台：原 Material FilledButton。
class AdaptiveGlassButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!isLiquidGlass) {
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

/// 平台感知的开关。iOS：liquidum GlassSwitch；其它平台：Material Switch。
class AdaptiveGlassSwitch extends StatelessWidget {
  const AdaptiveGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (!isLiquidGlass) {
      return material.Switch(value: value, onChanged: onChanged);
    }
    return GlassSwitch(value: value, onChanged: onChanged ?? (_) {});
  }
}
