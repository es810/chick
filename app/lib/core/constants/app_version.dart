/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.8.48';
  static const int build = 58;

  static String get label => '$name+$build';
}
