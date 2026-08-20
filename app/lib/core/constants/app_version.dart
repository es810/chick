/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.8.9';
  static const int build = 19;

  static String get label => '$name+$build';
}
