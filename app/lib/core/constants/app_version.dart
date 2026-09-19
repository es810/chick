/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.8.29';
  static const int build = 39;

  static String get label => '$name+$build';
}
