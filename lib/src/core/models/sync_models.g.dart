// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TimeSyncProps _$TimeSyncPropsFromJson(Map<String, dynamic> json) =>
    _TimeSyncProps(
      date: SyncDate.fromJson(json['date'] as Map<String, dynamic>),
      time: SyncTime.fromJson(json['time'] as Map<String, dynamic>),
      timezone: SyncTimeZone.fromJson(json['timezone'] as Map<String, dynamic>),
      is12HourFormat: json['is12HourFormat'] as bool? ?? false,
    );

Map<String, dynamic> _$TimeSyncPropsToJson(_TimeSyncProps instance) =>
    <String, dynamic>{
      'date': instance.date,
      'time': instance.time,
      'timezone': instance.timezone,
      'is12HourFormat': instance.is12HourFormat,
    };

_SyncDate _$SyncDateFromJson(Map<String, dynamic> json) => _SyncDate(
  year: (json['year'] as num).toInt(),
  month: (json['month'] as num).toInt(),
  day: (json['day'] as num).toInt(),
);

Map<String, dynamic> _$SyncDateToJson(_SyncDate instance) => <String, dynamic>{
  'year': instance.year,
  'month': instance.month,
  'day': instance.day,
};

_SyncTime _$SyncTimeFromJson(Map<String, dynamic> json) => _SyncTime(
  hour: (json['hour'] as num).toInt(),
  minute: (json['minute'] as num).toInt(),
  second: (json['second'] as num?)?.toInt() ?? 0,
  millisecond: (json['millisecond'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SyncTimeToJson(_SyncTime instance) => <String, dynamic>{
  'hour': instance.hour,
  'minute': instance.minute,
  'second': instance.second,
  'millisecond': instance.millisecond,
};

_SyncTimeZone _$SyncTimeZoneFromJson(Map<String, dynamic> json) =>
    _SyncTimeZone(
      offset: (json['offset'] as num).toInt(),
      dstOffset: (json['dstOffset'] as num?)?.toInt() ?? 0,
      id: json['id'] as String,
    );

Map<String, dynamic> _$SyncTimeZoneToJson(_SyncTimeZone instance) =>
    <String, dynamic>{
      'offset': instance.offset,
      'dstOffset': instance.dstOffset,
      'id': instance.id,
    };
