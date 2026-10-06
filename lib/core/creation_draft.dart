import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Each account and creation mode owns its draft; only prompt text is persisted.
class CreationDraft {
  CreationDraft(SharedPreferences prefs, String? userId, String mode,
      Map<String, TextEditingController> fields) {
    if (userId == null || userId.isEmpty) return;
    for (final field in fields.entries) {
      final key = 'creation_draft:$userId:$mode:${field.key}';
      field.value.text = prefs.getString(key) ?? '';
      void save() {
        unawaited(prefs.setString(key, field.value.text));
      }

      Timer? timer;
      void changed() {
        timer?.cancel();
        timer = Timer(const Duration(milliseconds: 350), save);
      }

      field.value.addListener(changed);
      _dispose.add(() {
        timer?.cancel();
        save();
        field.value.removeListener(changed);
      });
    }
  }
  final List<VoidCallback> _dispose = [];
  void dispose() {
    for (final dispose in _dispose) {
      dispose();
    }
  }
}
