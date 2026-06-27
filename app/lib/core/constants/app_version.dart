/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.5.0';
  static const int build = 7;

  static String get label => '$name+$build';
}
