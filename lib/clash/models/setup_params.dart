// lib/clash/models/setup_params.dart

class SetupParams {
  final String config;
  final SetupConfigParams params;

  const SetupParams({
    required this.config,
    required this.params,
  });
}

class SetupConfigParams {
  final String? profileId;
  final String? profileName;

  const SetupConfigParams({
    this.profileId,
    this.profileName,
  });
}
