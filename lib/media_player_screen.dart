import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({super.key});

  @override
  MediaPlayerScreenState createState() => MediaPlayerScreenState();
}

class MediaPlayerScreenState extends State<MediaPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  String? _fileType;
  String? _selectedFilePath;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4'],
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String extension = filePath.split('.').last;

      setState(() {
        _selectedFilePath = filePath;
        _fileType = (extension == 'mp3') ? 'audio' : 'video';
      });

      if (_fileType == 'audio') {
        await _loadAudioFile(filePath);
      } else {
        await _loadVideoFile(filePath);
      }
    }
  }

  Future<void> _loadAudioFile(String path) async {
    setState(() {
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
    });

    await _audioPlayer.setFilePath(path);
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _totalDuration = duration ?? Duration.zero;
      });
    });
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });
  }

  Future<void> _loadVideoFile(String path) async {
    setState(() {
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
    });
    
    _videoController = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        setState(() {
          _totalDuration = _videoController!.value.duration;
        });
        _videoController!.addListener(() {
          setState(() {
            _currentPosition = _videoController!.value.position;
          });
        });
      });
  }

  double _getVideoRotationAngle() {
    final orientation = _videoController!.value.size;
    if (orientation.width < orientation.height) {
      return 1.57;
    }
    return 0.0;
  }

  void _onSeek(double value) {
    final seekTo = Duration(seconds: value.toInt());
    if (_fileType == 'audio') {
      _audioPlayer.seek(seekTo);
    } else {
      _videoController?.seekTo(seekTo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Player'),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickFile,
              child: const Text('Select File'),
            ),
            const SizedBox(height: 20),
            _selectedFilePath != null
                ? _fileType == 'audio'
                    ? const Icon(Icons.music_note, size: 100)
                    : AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.5,
                          ),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Transform.rotate(
                              angle: _getVideoRotationAngle(),
                              child: SizedBox(
                                width: _videoController!.value.size.width,
                                height: _videoController!.value.size.height,
                                child: VideoPlayer(_videoController!),
                              ),
                            ),
                          ),
                        ),
                      )
                : const Text('No file selected'),
            const SizedBox(height: 20),
            _playbackControls(),
            _seekBar(),
          ],
        ),
      ),
    );
  }

  Widget _playbackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () {
            if (_fileType == 'audio') {
              _audioPlayer.play();
            } else {
              _videoController?.play();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.pause),
          onPressed: () {
            if (_fileType == 'audio') {
              _audioPlayer.pause();
            } else {
              _videoController?.pause();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.stop),
          onPressed: () {
            if (_fileType == 'audio') {
              _audioPlayer.stop();
              setState(() {
                _currentPosition = Duration.zero;
              });
            } else {
              _videoController?.pause();
              _videoController?.seekTo(Duration.zero);
              setState(() {
                _currentPosition = Duration.zero;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _seekBar() {
    return Slider(
      value: _currentPosition.inSeconds.toDouble().clamp(0, _totalDuration.inSeconds.toDouble()),
      min: 0,
      max: (_totalDuration.inSeconds > 0) ? _totalDuration.inSeconds.toDouble() : 1,
      onChanged: _totalDuration.inSeconds > 0 ? _onSeek : null,
      label: "${_currentPosition.inMinutes}:${_currentPosition.inSeconds % 60}",
    );
  }
}
