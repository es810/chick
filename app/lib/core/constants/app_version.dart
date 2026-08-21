/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.8.10';
  static const int build = 20;

  static String get label => '$name+$build';
}
