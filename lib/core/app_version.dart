class AppVersion {
  const AppVersion._();

  static const name = String.fromEnvironment(
    'RE0_VERSION_NAME',
    defaultValue: '1.2.0',
  );

  static const code = int.fromEnvironment(
    'RE0_VERSION_CODE',
    defaultValue: 10200,
  );

  static const releaseTag = String.fromEnvironment(
    'RE0_RELEASE_TAG',
    defaultValue: 'v1.2.0',
  );
}
