class DeviceLinking {
  final bool isEnabled;
  final String currentDeviceId;
  final String linkedDeviceId;

  DeviceLinking({
    required this.isEnabled,
    required this.currentDeviceId,
    required this.linkedDeviceId,
  });

  bool get isCurrentDeviceLinked => linkedDeviceId == currentDeviceId;
  bool get hasLinkedDevice => linkedDeviceId.isNotEmpty;
}
