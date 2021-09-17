import 'dart:io';

import 'package:binder/binder.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/repositories/speech_recognizer.dart';

enum PlayerState {
  noPermission,
  notReady,
  ready,
  playing,
  recording,
  processing
}

final playerLogicRef = LogicRef((scope) => PlayerLogic(scope));
final playerStateRef = StateRef<PlayerState>(PlayerState.noPermission);

class InternalPlayerState {
  FlutterSoundPlayer player;
  FlutterSoundRecorder recorder;
  late Directory docsDirectory;
  late Directory recordingsDirectory;
  InternalPlayerState(this.player, this.recorder);
}

final internalPlayerRef = StateRef(InternalPlayerState(
    FlutterSoundPlayer(logLevel: Level.warning),
    FlutterSoundRecorder(logLevel: Level.warning)));

final speechRecognizerRef = StateRef(SpeechRecognizer());

class PlayerLogic with Logic implements Loadable, Disposable {
  PlayerLogic(this.scope);

  InternalPlayerState get _internalPlayer => read(internalPlayerRef);

  @override
  final Scope scope;

  @override
  void dispose() {
    _internalPlayer.recorder.closeAudioSession();
    _internalPlayer.player.closeAudioSession();
  }

  Future<void> playNote(Note note, onDone) async {
    write(playerStateRef, PlayerState.playing);
    await _internalPlayer.player.startPlayer(
        codec: Codec.aacADTS,
        fromURI: note.filePath,
        whenFinished: () {
          write(playerStateRef, PlayerState.ready);
          onDone();
        });
  }

  Future<void> stopPlaying() async {
    await _internalPlayer.player.stopPlayer();
    write(playerStateRef, PlayerState.ready);
  }

  Future<void> startRecording(Note note) async {
    await _internalPlayer.recorder
        .startRecorder(codec: Codec.aacADTS, toFile: note.filePath);
    write(playerStateRef, PlayerState.recording);
  }

  Future<Duration?> stopRecording({Note? note}) async {
    await _internalPlayer.recorder.stopRecorder();
    if (note == null) {
      return null;
    }
    final duration = await flutterSoundHelper.duration(note.filePath);
    return duration;
  }

  Future<void> tryPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException("Could not get microphone permission");
    } else {
      await load();
    }
  }

  @override
  Future<void> load() async {
    final granted = await Permission.microphone.isGranted;
    if (granted) {
      write(playerStateRef, PlayerState.notReady);
      try {
        _internalPlayer.docsDirectory =
            await getApplicationDocumentsDirectory();
        _internalPlayer.recordingsDirectory =
            await Directory("${_internalPlayer.docsDirectory.path}/recordings")
                .create(recursive: true);
        // TODO: play from headphones IF AVAILABLE
        await _internalPlayer.player.openAudioSession();
        await _internalPlayer.recorder.openAudioSession();
        await read(speechRecognizerRef).init();
        write(playerStateRef, PlayerState.ready);
      } catch (e) {
        write(playerStateRef, PlayerState.notReady);
        print(e);
      }
    }
  }
}
