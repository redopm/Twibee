import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../theme.dart';

class AudioMessageWidget extends StatefulWidget {
  final String url;
  
  const AudioMessageWidget({super.key, required this.url});
  
  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (widget.url.startsWith('http')) {
        await _audioPlayer.play(UrlSource(widget.url));
      } else {
        await _audioPlayer.play(DeviceFileSource(widget.url));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.orange,
            child: IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: AppColors.white, size: 20),
              onPressed: _togglePlay,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 2.5,
              ),
              child: Slider(
                activeColor: AppColors.orange,
                inactiveColor: AppColors.grey.withValues(alpha: 0.3),
                min: 0,
                max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1,
                value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1),
                onChanged: (value) async {
                  final position = Duration(seconds: value.toInt());
                  await _audioPlayer.seek(position);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

