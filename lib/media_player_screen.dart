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
      _initializeFile(filePath);
    }
  }

  void _initializeFile(String filePath) {
    String extension = filePath.split('.').last;
    setState(() {
      _selectedFilePath = filePath;
      _fileType = extension == 'mp3' ? 'audio' : 'video';
    });

    if (_fileType == 'audio') {
      _loadAudioFile(filePath);
    } else {
      _loadVideoFile(filePath);
    }
  }

  Future<void> _loadAudioFile(String path) async {
    setState(() {
      _resetMediaPosition();
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
    _videoController = VideoPlayerController.file(File(path));

    await _videoController!.initialize();
    setState(() {
      _resetMediaPosition();
      _totalDuration = _videoController!.value.duration;
    });

    _videoController!.addListener(() {
      if (mounted) {
        setState(() {
          _currentPosition = _videoController!.value.position;
        });
      }
    });
  }

  void _resetMediaPosition() {
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
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
      appBar: AppBar(title: const Text('Media Player')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFilePickerButton(),
          const SizedBox(height: 20),
          _buildMediaDisplay(context),
          const SizedBox(height: 20),
          _playbackControls(),
          const SizedBox(height: 20),
          _seekBar(),
        ],
      ),
    );
  }

  Widget _buildFilePickerButton() {
    return ElevatedButton(
      onPressed: _pickFile,
      child: const Text('Select File'),
    );
  }

  Widget _buildMediaDisplay(BuildContext context) {
    if (_selectedFilePath == null) {
      return const Icon(Icons.video_library, size: 100);
    }
    return _fileType == 'audio'
        ? const Icon(Icons.music_note, size: 100)
        : _buildConstrainedVideoPlayer(context);
  }

  Widget _buildConstrainedVideoPlayer(BuildContext context) {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const CircularProgressIndicator();
    }

    bool isPortrait = _videoController!.value.aspectRatio < 1.0;
    return Center(
      child: Container(
        height: isPortrait
            ? MediaQuery.of(context).size.height * 0.5
            : MediaQuery.of(context).size.height * 0.35,
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Transform.rotate(
            angle: isPortrait ? 90 * 3.1416 / 180 : 0,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: isPortrait
                    ? _videoController!.value.size.height
                    : _videoController!.value.size.width,
                height: isPortrait
                    ? _videoController!.value.size.width
                    : _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _playbackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(Icons.play_arrow, _playMedia),
        _buildControlButton(Icons.pause, _pauseMedia),
        _buildControlButton(Icons.stop, _stopMedia),
      ],
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return IconButton(icon: Icon(icon), onPressed: onPressed);
  }

  void _playMedia() {
    if (_fileType == 'audio') {
      _audioPlayer.play();
    } else {
      _videoController?.play();
    }
  }

  void _pauseMedia() {
    if (_fileType == 'audio') {
      _audioPlayer.pause();
    } else {
      _videoController?.pause();
    }
  }

  void _stopMedia() {
    if (_fileType == 'audio') {
      _audioPlayer.stop();
    } else {
      _videoController?.pause();
      _videoController?.seekTo(Duration.zero);
    }
    setState(() {
      _currentPosition = Duration.zero;
    });
  }

  Widget _seekBar() {
    double currentPos = _currentPosition.inSeconds.toDouble();
    double maxPos = _totalDuration.inSeconds.toDouble();
    double value = currentPos.clamp(0, maxPos);

    return Slider(
      value: value,
      min: 0,
      max: maxPos > 0 ? maxPos : 1,
      onChanged: maxPos > 0 ? _onSeek : null,
      label: "${_currentPosition.inMinutes}:${_currentPosition.inSeconds % 60}",
    );
  }
}
