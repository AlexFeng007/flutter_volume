import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

@immutable
class VolumeVal {
  final double vol;
  final int type;

  VolumeVal({
    @required this.vol,
    @required this.type,
  })  : assert(vol != null),
        assert(type != null);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VolumeVal && hashCode == other.hashCode);

  @override
  int get hashCode => hashValues(vol, type);
}

class _VolumeValueNotifier extends ValueNotifier<VolumeVal> {
  _VolumeValueNotifier(VolumeVal value) : super(value);
}

typedef VolumeCallback = void Function(VolumeVal value);

class FlutterVolume {
  static const int STREAM_VOICE_CALL = 0;
  static const int STREAM_SYSTEM = 1;
  static const int STREAM_RING = 2;
  static const int STREAM_MUSIC = 3;
  static const int STREAM_ALARM = 4;

  static const double _step = 1.0 / 16.0;
  static const MethodChannel _channel =
      const MethodChannel('com.waitingTok.flutter_volume');

  static _VolumeValueNotifier _notifier =
      _VolumeValueNotifier(VolumeVal(vol: 0, type: 0));
  static StreamSubscription _eventSubs;

  static void enableWatcher() async {
    if (_eventSubs == null) {
      await _channel.invokeMethod("enable_watch");
      _eventSubs = EventChannel('com.waitingTok.flutter_volume/event')
          .receiveBroadcastStream()
          .listen(_eventListener, onError: _errorListener);
    }
  }

  static void disableWatcher() async {
    _eventSubs?.cancel();
    await _channel.invokeMethod("disable_watch");
    _eventSubs = null;
  }

  static void _eventListener(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    switch (map['event']) {
      case 'vol':
        double vol = map['v'];
        int type = map['t'];
        _notifier.value = VolumeVal(vol: vol, type: type);
        break;
      default:
        break;
    }
  }

  static void _errorListener(Object obj) {
    print("errorListener: $obj");
  }

  static Future<double> up({
    double step = _step,
    int type = STREAM_MUSIC,
  }) {
    return _channel.invokeMethod("up", <String, dynamic>{
      'step': step,
      'type': type,
    });
  }

  static Future<double> down({
    double step = _step,
    int type = STREAM_MUSIC,
  }) {
    return _channel.invokeMethod("down", <String, dynamic>{
      'step': step,
      'type': type,
    });
  }

  static Future<double> mute({
    int type = STREAM_MUSIC,
  }) {
    return _channel.invokeMethod("mute", <String, dynamic>{
      'type': type,
    });
  }

  static Future<double> get({
    int type = STREAM_MUSIC,
  }) {
    return _channel.invokeMethod("get", <String, dynamic>{
      'type': type,
    });
  }

  static Future<double> set(double vol, {int type = STREAM_MUSIC}) {
    return _channel.invokeMethod("set", <String, dynamic>{
      'vol': vol,
      'type': type,
    });
  }

  // 官方赠送的测试方法，模仿这个写 invokeMethod 即可
  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static void addVolListener(VoidCallback listener) {
    _notifier.addListener(listener);
  }

  static void removeVolListener(VoidCallback listener) {
    _notifier.removeListener(listener);
  }

  static VolumeVal get value => _notifier.value;
}

class VolumeWatcher extends StatefulWidget {
  final VolumeCallback watcher;
  final Widget child;

  VolumeWatcher({
    @required this.watcher,
    @required this.child,
  })  : assert(child != null),
        assert(watcher != null);

  @override
  _VolumeWatcherState createState() => _VolumeWatcherState();
}

class _VolumeWatcherState extends State<VolumeWatcher> {
  @override
  void initState() {
    super.initState();
    FlutterVolume.enableWatcher();
    FlutterVolume.addVolListener(_volListener);
  }

  void _volListener() {
    VolumeVal value = FlutterVolume.value;
    widget.watcher(value);
  }

  @override
  void dispose() {
    super.dispose();
    FlutterVolume.removeVolListener(_volListener);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
