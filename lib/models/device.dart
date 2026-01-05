class Device {
  final int id;
  final String imei;
  final String brand;
  final String model;
  final int? phoneModelId;
  final String lockStatus;
  final bool isLocked;

  Device({
    required this.id,
    required this.imei,
    required this.brand,
    required this.model,
    this.phoneModelId,
    required this.lockStatus,
    required this.isLocked,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      imei: json['imei'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      phoneModelId: json['phone_model_id'] as int?,
      lockStatus: json['lock_status'] as String,
      isLocked: json['is_locked'] as bool,
    );
  }

  String get fullName => '$brand $model';
}
