//
//  FlutterVolumePlugin.m
//  flutter_volume
//
//  Created by YaphetS(PGTwo) on 2020/10/14.
//
#import "FlutterVolumePlugin.h"
#import "QueuingEventSink.h"
#import <AVKit/AVKit.h>
#import <Flutter/Flutter.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation FlutterVolumePlugin {
    NSObject<FlutterPluginRegistrar> *_registrar;
    QueuingEventSink *_eventSink;
    FlutterEventChannel *_eventChannel;
      
    MPVolumeView *_volumeView;
    UISlider *_volumeViewSlider;
    BOOL _volumeInWindow;
    BOOL _eventListening;
    float _volStep;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"com.waitingTok.flutter_volume"
            binaryMessenger:[registrar messenger]];
  FlutterVolumePlugin* instance = [[FlutterVolumePlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithRegistrar:
    (NSObject<FlutterPluginRegistrar> *)registrar {
  self = [super init];
  if (self) {
    _registrar = registrar;
    _eventListening = FALSE;
    _volStep = 1.0 / 16.0;
    _eventSink = [[QueuingEventSink alloc] init];
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary *argsMap = call.arguments;
    if ([@"up" isEqualToString:call.method]) {
      NSNumber *number = argsMap[@"step"];
      float step = number == nil ? _volStep : [number floatValue];
      float vol = [self getVolume];
      vol += step;
      vol = [self setVolume:vol];
      result(@(vol));
    } else if ([@"down" isEqualToString:call.method]) {
      NSNumber *number = argsMap[@"step"];
      float step = number == nil ? _volStep : [number floatValue];
      float vol = [self getVolume];
      vol -= step;
      vol = [self setVolume:vol];
      result(@(vol));
    } else if ([@"mute" isEqualToString:call.method]) {
      float vol = [self setVolume:0.0f];
      result(@(vol));
    } else if ([@"set" isEqualToString:call.method]) {
      NSNumber *number = argsMap[@"vol"];
      float v = number == nil ? [self getVolume] : [number floatValue];
      v = [self setVolume:v];
      result(@(v));
    } else if ([@"get" isEqualToString:call.method]) {
      result(@([self getVolume]));
    } else if ([@"enable_watch" isEqualToString:call.method]) {
      [self enableWatch];
      result(nil);
    } else if ([@"disable_watch" isEqualToString:call.method]) {
      [self disableWatch];
      result(nil);
    }
}

- (void)initVolumeView {
  if (_volumeView == nil) {
    _volumeView =
        [[MPVolumeView alloc] initWithFrame:CGRectMake(-100, -100, 10, 10)];
    _volumeView.hidden = YES;
  }
  if (_volumeViewSlider == nil) {
    for (UIView *view in [_volumeView subviews]) {
      if ([view.class.description isEqualToString:@"MPVolumeSlider"]) {
        _volumeViewSlider = (UISlider *)view;
        break;
      }
    }
  }
  if (!_volumeInWindow) {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (window != nil) {
      [window addSubview:_volumeView];
      _volumeInWindow = YES;
    }
  }
}

- (float)getVolume {
  [self initVolumeView];
  if (_volumeViewSlider == nil) {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    CGFloat currentVol = audioSession.outputVolume;
    return currentVol;
  } else {
    return _volumeViewSlider.value;
  }
}

- (float)setVolume:(float)vol {
  [self initVolumeView];
  if (vol > 1.0) {
    vol = 1.0;
  } else if (vol < 0) {
    vol = 0.0;
  }
  [_volumeViewSlider setValue:vol animated:FALSE];
  vol = _volumeViewSlider.value;
  return vol;
}

- (void)enableWatch {
  if (_eventListening == NO) {
    _eventListening = YES;

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(volumeChange:)
               name:@"AVSystemController_SystemVolumeDidChangeNotification"
             object:nil];
      
    _eventChannel = [FlutterEventChannel
                    eventChannelWithName:@"com.befovy.flutter_volume/event"
                    binaryMessenger:[_registrar messenger]];
    [_eventChannel setStreamHandler:self];
  }
}

- (void)disableWatch {
  if (_eventListening == YES) {
    _eventListening = NO;

    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:@"AVSystemController_SystemVolumeDidChangeNotification"
                object:nil];
    [_eventChannel setStreamHandler:nil];
    _eventChannel = nil;
  }
}

- (void)volumeChange:(NSNotification *)notification {
  NSString *style = [notification.userInfo
      objectForKey:@"AVSystemController_AudioCategoryNotificationParameter"];
  CGFloat value = [[notification.userInfo
      objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"]
      doubleValue];
  if ([style isEqualToString:@"Audio/Video"]) {
    [self sendVolumeChange:value];
  }
}

- (void)sendVolumeChange:(float)value {
  if (_eventListening) {
      NSLog(@"valume val %f\n", value);
    [_eventSink success:@{@"event" : @"vol", @"v" : @(value)}];
  }
}

- (FlutterError *_Nullable)onCancelWithArguments:(id _Nullable)arguments {
  [_eventSink setDelegate:nil];
  return nil;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:
                                           (nonnull FlutterEventSink)events {
  [_eventSink setDelegate:events];
  return nil;
}

@end
