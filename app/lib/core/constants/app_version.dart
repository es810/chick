/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.8.24';
  static const int build = 34;

  static String get label => '$name+$build';
}
