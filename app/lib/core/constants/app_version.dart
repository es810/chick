/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.8.3';
  static const int build = 13;

  static String get label => '$name+$build';
}
