bool isObservableCommand(String method) {
  if (method.startsWith('debug.') || method == 'logs.recent') return false;
  return !const {
    'status',
    'device.snapshot',
    'device.status',
    'device.refresh.battery',
    'creator.github.status',
  }.contains(method);
}

Map<String, Object?> safeCommandLogParams(Map<String, Object?> params) {
  const allowed = {
    'provider',
    'source',
    'resource',
    'device',
    'role',
    'fileName',
    'mediaType',
    'position',
    'page',
    'limit',
    'sort',
    'type',
    'id',
    'package',
    'target',
    'assetType',
    'archived',
    'pluginId',
    'operation',
  };
  final result = <String, Object?>{};
  for (final entry in params.entries) {
    if (entry.key == 'command' && entry.value is Map) {
      final command = (entry.value as Map).cast<Object?, Object?>();
      result['command'] = command['method']?.toString() ?? 'unknown';
      continue;
    }
    if (!allowed.contains(entry.key)) continue;
    final value = entry.value;
    result[entry.key] = switch (value) {
      null || num() || bool() => value,
      String text => _safeString(entry.key, text),
      List values => '<list:${values.length}>',
      Map values => '<map:${values.length}>',
      _ => '<${value.runtimeType}>',
    };
  }
  return result;
}

String _safeString(String key, String value) {
  if (key == 'fileName') return value.split(RegExp(r'[/\\]')).last;
  if (value.length <= 160) return value;
  return '${value.substring(0, 157)}...';
}
