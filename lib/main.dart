import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/oronbox_app.dart';
import 'package:oronbox/src/app/window/desktop_window_bootstrap.dart';
import 'package:oronbox/src/app/window/debug_window_preference.dart';
import 'package:oronbox/src/app/window/window_launch_spec.dart';
import 'package:oronbox/src/app/window/window_launcher.dart';
import 'package:oronbox/src/cli/cli_entrypoint.dart';
import 'package:oronbox/src/core/logging/bluetooth_log.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/logging/diagnostic_event.dart';
import 'package:oronbox/src/core/services/license_registry_service.dart';
import 'package:oronbox/src/core/services/bluetooth_permission_bootstrap.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/host/gui_host_overrides.dart';
import 'package:oronbox/src/features/devices/widgets/device_deep_link_handler.dart';
import 'package:oronbox/src/features/debug/pages/debug_window_app.dart';
import 'package:oronbox/src/features/plugins/pages/plugin_window_app.dart';

// ============================================================================
// iOS 启动诊断（2026-10-25 追加，排障期专用，定位后可整体移除）
//
// 背景：OronBox 首次 iOS 化后在设备上白屏——Flutter 进程活着（图标能启动），
// 但 Dart 侧 runApp 之前某步抛了异常，或 runApp 之后首帧渲染失败。release
// 模式下 Dart 未捕获异常被静默丢弃，屏幕上什么都不显示，无法定位。
//
// 对策：
// 1. 启动链每步记入 [_startupTrace]；
// 2. main 整体包进 runZonedGuarded，未捕获异步错误上屏；
// 3. runApp 之前失败 → 直接渲染红色诊断页；
// 4. widget build 失败 → ErrorWidget.builder 替换为可见错误块；
// 5. 启动链 30 秒未到 runApp / runApp 后 6 秒无首帧 → 看门狗报「卡住」。
// 正常路径行为零变化。
// ============================================================================
final List<String> _startupTrace = <String>[];
bool _appDispatched = false;
bool _firstFrameSeen = false;
bool _diagnosticShown = false;
Timer? _launchWatchdog;
Timer? _firstFrameWatchdog;

void _trace(String step) {
  _startupTrace.add('${DateTime.now().millisecondsSinceEpoch ~/ 1000}s $step');
}

void _armWatchdogs() {
  // 整个启动链 30 秒都没走到 runApp：某步 await 永远不返回。
  _launchWatchdog = Timer(const Duration(seconds: 30), () {
    if (_appDispatched || _diagnosticShown) return;
    _reportDiagnostic(
      '启动链 30 秒未到达 runApp（某一步 await 卡住）',
      StateError('launch watchdog fired'),
      StackTrace.current,
    );
  });
  // runApp 之后 6 秒仍没有首帧：事件循环卡死或首帧 build 挂起。
  _firstFrameWatchdog = Timer(const Duration(seconds: 36), () {
    if (!_appDispatched || _firstFrameSeen || _diagnosticShown) return;
    _reportDiagnostic(
      'runApp 后首帧超时未渲染',
      StateError('first-frame watchdog fired'),
      StackTrace.current,
    );
  });
}

void _installDiagnosticHooks() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    _reportDiagnostic('Flutter 框架错误', details.exception, details.stackTrace);
    if (previousOnError != null) {
      previousOnError(details);
    }
  };
  ErrorWidget.builder = (details) => _BuildErrorBanner(details: details);
  final previousPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    _reportDiagnostic('平台层未捕获错误', error, stack);
    return previousPlatformError?.call(error, stack) ?? false;
  };
}

void _reportDiagnostic(String title, Object error, StackTrace? stackTrace) {
  final body = StringBuffer()
    ..writeln('【$title】')
    ..writeln()
    ..writeln('错误: $error')
    ..writeln()
    ..writeln('堆栈(前40行):')
    ..writeln(stackTrace.toString().split('\n').take(40).join('\n'))
    ..writeln()
    ..writeln('启动轨迹:')
    ..writeln(_startupTrace.join('\n'));
  final text = body.toString();
  // 连 Xcode / Console 时可见；写文件失败也不影响排障。
  // ignore: avoid_print
  print('===== iOS STARTUP DIAGNOSTIC =====\n$text\n===== END =====');
  if (_diagnosticShown) return;
  _diagnosticShown = true;
  _launchWatchdog?.cancel();
  _firstFrameWatchdog?.cancel();
  runApp(_StartupDiagnosticApp(text));
}

void main(List<String> args) async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _installDiagnosticHooks();
      _armWatchdogs();
      _trace('ensureInitialized ok');
      final startupStopwatch = Stopwatch()..start();
      final window = WindowLaunchSpec.parse(args);
      _trace('WindowLaunchSpec role=${window.role.name}');
      final process = switch (window.role) {
        OronBoxWindowRole.debug => DiagnosticProcess.debugWindow,
        OronBoxWindowRole.plugin => DiagnosticProcess.pluginWindow,
        OronBoxWindowRole.main =>
          args.contains('--nogui')
              ? args.contains('daemon') && args.contains('run')
                    ? DiagnosticProcess.backend
                    : DiagnosticProcess.cli
              : DiagnosticProcess.frontend,
      };
      await initLogging(arguments: args, process: process);
      _trace('initLogging ok');
      initBluetoothLogging();
      installGlobalErrorLogging();
      _trace('logging + bluetooth verbose installed');
      await SharedPrefsService.instance.init();
      _trace('SharedPrefsService init ok');
      await runCliIfRequested(args);
      _trace('runCliIfRequested done');
      if (!await initializeWindowCoordinator(window, launchArguments: args)) {
        _trace('window coordinator returned false, exit');
        return;
      }
      _trace('window coordinator ok');
      if (window.role == OronBoxWindowRole.main) {
        await requestBluetoothPermissionOnStartup();
        _trace('requestBluetoothPermissionOnStartup done');
      }
      await LicenseRegistryService.registerThirdPartyLicenses();
      _trace('third-party licenses registered');
      await initializeDesktopWindow(spec: window);
      _trace('initializeDesktopWindow done');
      runApp(
        ProviderScope(
          overrides: [
            ...guiHostOverrides(),
            initialDeepLinksProvider.overrideWithValue(args),
          ],
          child: switch (window.role) {
            OronBoxWindowRole.debug => const DebugWindowApp(),
            OronBoxWindowRole.plugin => PluginWindowApp(
              pluginId: window.targetId ?? '',
            ),
            OronBoxWindowRole.main => const OronBoxApp(),
          },
        ),
      );
      _appDispatched = true;
      _launchWatchdog?.cancel();
      _trace('runApp dispatched');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _firstFrameSeen = true;
        _firstFrameWatchdog?.cancel();
        _trace('first frame rendered');
      });
      startupStopwatch.stop();
      logDiagnostic(
        getLogger('Application'),
        Level.INFO,
        'OronBox startup completed',
        fields: {
          'durationMs': startupStopwatch.elapsedMilliseconds,
          'role': process.name,
        },
      );
      if (window.isSecondary) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(notifySecondaryWindowReady());
        });
      }
      if (window.role == OronBoxWindowRole.main &&
          !args.contains('--nogui') &&
          supportsSecondaryWindows &&
          isDebugWindowEnabled()) {
        unawaited(() async {
          if (!await openDebugWindow()) {
            await setDebugWindowEnabled(false);
          }
        }());
      }
    },
    (error, stackTrace) {
      _reportDiagnostic('未捕获异步错误（Zone）', error, stackTrace);
    },
  );
}

/// 启动失败时直接替换 root 的红色诊断页。纯 Text，零依赖，保证自身不崩。
class _StartupDiagnosticApp extends StatelessWidget {
  const _StartupDiagnosticApp(this.body);

  final String body;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF7F1D1D),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectionArea(
              child: Text(
                'OronBox iOS 启动诊断\n'
                '（请全屏截图发给开发者，然后杀掉 App 重开）\n'
                '\n'
                '$body',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 12,
                  height: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// widget build 失败时的可见错误块（release 下默认只显示灰色占位）。
class _BuildErrorBanner extends StatelessWidget {
  const _BuildErrorBanner({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFB71C1C),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: SelectionArea(
          child: Text(
            'Widget 构建错误（请截图）\n\n${details.exception}\n\n'
            '${details.stack.toString().split('\n').take(20).join('\n')}',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 11,
              height: 1.4,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
