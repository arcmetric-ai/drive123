import 'package:flutter/foundation.dart';

/// Simple app-wide notifier used to broadcast lightweight events between
/// independent screens. Currently used to signal that lessons/upcoming data
/// changed and screens should refresh.
class AppNotifier extends ChangeNotifier {
  AppNotifier._internal();

  static final AppNotifier _instance = AppNotifier._internal();

  static AppNotifier get instance => _instance;

  /// Call this when lessons or schedule-affecting data changes.
  void notifyLessonsChanged() {
    notifyListeners();
  }
}
