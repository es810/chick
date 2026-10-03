/// Keep in sync with `pubspec.yaml` version (name + build number).
class AppVersion {
  static const String name = '1.8.41';
  static const int build = 51;

  static String get label => '$name+$build';
}
