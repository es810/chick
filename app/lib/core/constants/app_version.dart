/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.1.0';
  static const int build = 3;

  static String get label => '$name+$build';
}
