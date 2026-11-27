/// A snapshot of the instantaneous health-related state reported by a Xiaomi
/// wearable.
///
/// The nullable fields are deliberately nullable: a device can report a
/// partial `BasicStatus.Report` packet, and an unknown value must not be
/// silently converted into a real state.
class XiaomiHealthState {
  const XiaomiHealthState({
    this.isCharging,
    this.isWearing,
    this.isSleeping,
    this.battery,
    this.chargingStatus,
    this.wearingStatus,
    this.sleepingStatus,
    this.warningStatus,
    this.sportType,
    this.sportState,
  });

  final bool? isCharging;
  final bool? isWearing;
  final bool? isSleeping;
  final int? battery;

  /// The last protocol event code, not a boolean snapshot.
  ///
  /// Charging uses 1/2/3 (start/quit/finish), while wearing and sleeping use
  /// 1/2 (on/off and in/out respectively).
  final int? chargingStatus;
  final int? wearingStatus;
  final int? sleepingStatus;
  final int? warningStatus;
  final int? sportType;
  final int? sportState;

  Map<String, Object?> toJson() => {
    if (isCharging != null) 'isCharging': isCharging,
    if (isWearing != null) 'isWearing': isWearing,
    if (isSleeping != null) 'isSleeping': isSleeping,
    if (battery != null) 'battery': battery,
    if (chargingStatus != null) 'chargingStatus': chargingStatus,
    if (wearingStatus != null) 'wearingStatus': wearingStatus,
    if (sleepingStatus != null) 'sleepingStatus': sleepingStatus,
    if (warningStatus != null) 'warningStatus': warningStatus,
    if (sportType != null) 'sportType': sportType,
    if (sportState != null) 'sportState': sportState,
  };

  factory XiaomiHealthState.fromJson(Map<String, dynamic> json) =>
      XiaomiHealthState(
        isCharging: json['isCharging'] as bool?,
        isWearing: json['isWearing'] as bool?,
        isSleeping: json['isSleeping'] as bool?,
        battery: (json['battery'] as num?)?.toInt(),
        chargingStatus: (json['chargingStatus'] as num?)?.toInt(),
        wearingStatus: (json['wearingStatus'] as num?)?.toInt(),
        sleepingStatus: (json['sleepingStatus'] as num?)?.toInt(),
        warningStatus: (json['warningStatus'] as num?)?.toInt(),
        sportType: (json['sportType'] as num?)?.toInt(),
        sportState: (json['sportState'] as num?)?.toInt(),
      );

  XiaomiHealthState copyWith({
    bool? isCharging,
    bool? isWearing,
    bool? isSleeping,
    int? battery,
    int? chargingStatus,
    int? wearingStatus,
    int? sleepingStatus,
    int? warningStatus,
    int? sportType,
    int? sportState,
  }) {
    return XiaomiHealthState(
      isCharging: isCharging ?? this.isCharging,
      isWearing: isWearing ?? this.isWearing,
      isSleeping: isSleeping ?? this.isSleeping,
      battery: battery ?? this.battery,
      chargingStatus: chargingStatus ?? this.chargingStatus,
      wearingStatus: wearingStatus ?? this.wearingStatus,
      sleepingStatus: sleepingStatus ?? this.sleepingStatus,
      warningStatus: warningStatus ?? this.warningStatus,
      sportType: sportType ?? this.sportType,
      sportState: sportState ?? this.sportState,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is XiaomiHealthState &&
      other.isCharging == isCharging &&
      other.isWearing == isWearing &&
      other.isSleeping == isSleeping &&
      other.battery == battery &&
      other.chargingStatus == chargingStatus &&
      other.wearingStatus == wearingStatus &&
      other.sleepingStatus == sleepingStatus &&
      other.warningStatus == warningStatus &&
      other.sportType == sportType &&
      other.sportState == sportState;

  @override
  int get hashCode => Object.hash(
    isCharging,
    isWearing,
    isSleeping,
    battery,
    chargingStatus,
    wearingStatus,
    sleepingStatus,
    warningStatus,
    sportType,
    sportState,
  );
}
