import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Trade-Portal / MT5-style trade sounds: success chime on order
/// executed, error tone on rejection (same mp3 files as portal).
class TradeSound {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> ok() async {
    HapticFeedback.mediumImpact();
    try {
      await _player.stop();
      await _player.setVolume(0.8);
      await _player.play(AssetSource('sounds/success.mp3'));
    } catch (_) {}
  }

  static Future<void> error() async {
    HapticFeedback.heavyImpact();
    try {
      await _player.stop();
      await _player.setVolume(0.8);
      await _player.play(AssetSource('sounds/error.mp3'));
    } catch (_) {}
  }
}
