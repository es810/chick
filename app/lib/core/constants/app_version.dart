/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.8.27';
  static const int build = 37;

  static String get label => '$name+$build';
}
