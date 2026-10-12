import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:flutter/foundation.dart';

abstract class ViewModel extends ChangeNotifier {
  bool _disposed = false;
  final _effects = <UiEffect>[];

  bool get isDisposed => _disposed;

  void emitEffect(UiEffect effect) {
    if (_disposed) return;
    _effects.add(effect);
    notifyListeners();
  }

  List<UiEffect> drainEffects() {
    final result = List<UiEffect>.of(_effects);
    _effects.clear();
    return result;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _effects.clear();
    super.dispose();
  }
}
