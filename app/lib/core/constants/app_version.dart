/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.8.25';
  static const int build = 35;

  static String get label => '$name+$build';
}
