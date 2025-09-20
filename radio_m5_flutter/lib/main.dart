import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:share_plus/share_plus.dart';

const STREAM_URL = "https://stream.zeno.fm/1jvkvcwkoq3tv";
const RADIO_NAME = "Radio M5 93.5 FM";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize just_audio_background to allow lockscreen controls & notifications
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.radio.m5.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  // Init AudioService with a background AudioHandler that wraps just_audio
  final audioHandler = await AudioService.init(
    builder: () => RadioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.radio.m5.channel.audio',
      androidNotificationChannelName: 'Radio M5 Playback',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(MyApp(audioHandler: audioHandler));
}

class MyApp extends StatelessWidget {
  final AudioHandler audioHandler;
  const MyApp({required this.audioHandler, super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<AudioHandler>.value(
      value: audioHandler,
      child: MaterialApp(
        title: RADIO_NAME,
        theme: ThemeData.dark(),
        home: const RadioHomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class RadioAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  RadioAudioHandler() {
    // Broadcast playback state changes
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.connecting,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });
  }

  @override
  Future<void> play() async {
    try {
      if (_player.playing) return;
      // set source if not already
      if (_player.audioSource == null) {
        final mediaItem = MediaItem(
          id: STREAM_URL,
          album: RADIO_NAME,
          title: RADIO_NAME,
          artUri: Uri.parse('asset:///assets/logo.png'),
        );
        // announce current media
        mediaItem.addToStream(); // helper below
        mediaItem.addToStream = null;
        mediaItem.addToStream;
        mediaItemStream.add(mediaItem);
        await _player.setAudioSource(AudioSource.uri(Uri.parse(STREAM_URL)));
      }
      await _player.play();
    } catch (e) {
      // ignore for now
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _player.dispose();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);
}

// tiny extension to push a MediaItem into mediaItem stream
extension on MediaItem {
  static final _controller = StreamController<MediaItem>.broadcast();
  Stream<MediaItem> get stream => _controller.stream;
  void addToMediaItem() => _controller.add(this);
}

// UI
class RadioHomePage extends StatefulWidget {
  const RadioHomePage({super.key});

  @override
  State<RadioHomePage> createState() => _RadioHomePageState();
}

class _RadioHomePageState extends State<RadioHomePage> {
  late final AudioHandler _audioHandler;

  @override
  void initState() {
    super.initState();
    _audioHandler = Provider.of<AudioHandler>(context, listen: false);
  }

  Widget buildPlayButton(PlaybackState state) {
    final playing = state.playing;
    return ElevatedButton.icon(
      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      label: Text(playing ? 'Pause' : 'Écouter'),
      onPressed: () {
        if (playing) {
          _audioHandler.pause();
        } else {
          _audioHandler.play();
        }
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = Provider.of<AudioHandler>(context, listen: false);
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      initialData: audioHandler.playbackState.value,
      builder: (context, snapshot) {
        final state = snapshot.data ?? PlaybackState();
        return Scaffold(
          appBar: AppBar(
            title: const Text(RADIO_NAME),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => Share.share('Écoute $RADIO_NAME: $STREAM_URL'),
              ),
            ],
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', width: 200, height: 200),
                const SizedBox(height: 20),
                const Text(RADIO_NAME, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                buildPlayButton(state),
                const SizedBox(height: 16),
                StreamBuilder<MediaItem?>(
                  stream: audioHandler.mediaItem,
                  builder: (context, snap) {
                    final item = snap.data;
                    return Text(item?.title ?? 'Aucun titre', style: const TextStyle(fontSize: 14));
                  },
                ),
                const SizedBox(height: 8),
                const Text('Flux : https://stream.zeno.fm/1jvkvcwkoq3tv', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool autoplay = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              value: autoplay,
              onChanged: (v) => setState(() => autoplay = v),
              title: const Text('Lecture automatique au démarrage'),
            ),
            ListTile(
              title: const Text('URL de stream'),
              subtitle: const Text(STREAM_URL),
            ),
          ],
        ),
      ),
    );
  }
}
