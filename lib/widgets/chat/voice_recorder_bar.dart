import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme.dart';

class VoiceRecorderBar extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(String) onSend;
  
  const VoiceRecorderBar({super.key, required this.onCancel, required this.onSend});
  
  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  String? _audioPath;
  Timer? _durationTimer;
  int _recordDuration = 0;
  StreamSubscription? _amplitudeSubscription;
  final List<double> _amplitudes = [];

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (hasPermission) {
        final dir = await getTemporaryDirectory();
        _audioPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000), 
          path: _audioPath!
        );
        
        if (mounted) {
          setState(() {
            _isRecording = true;
            _isPaused = false;
          });
        }
        _startTimer();
        
        // Listen to amplitude stream to draw custom waveform
        _amplitudeSubscription = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 50)).listen((amp) {
          if (_isPaused) return;
          // Normalize amplitude from roughly -50dB..0dB to 0.0..1.0
          double normalized = (amp.current + 50) / 50;
          normalized = normalized.clamp(0.05, 1.0); // minimum bar height
          if (mounted) {
            setState(() {
              _amplitudes.add(normalized);
              if (_amplitudes.length > 50) {
                _amplitudes.removeAt(0);
              }
            });
          }
        });
      } else {
        widget.onCancel();
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start recording: $e')));
      }
      widget.onCancel();
    }
  }
  
  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() => _recordDuration++);
      }
    });
  }

  Future<void> _togglePause() async {
    try {
      if (_isPaused) {
        await _audioRecorder.resume();
        if (mounted) setState(() => _isPaused = false);
      } else {
        await _audioRecorder.pause();
        if (mounted) setState(() => _isPaused = true);
      }
    } catch (e) {
      debugPrint('Error toggling pause: $e');
    }
  }

  Future<void> _stopAndSend() async {
    try {
      _durationTimer?.cancel();
      _amplitudeSubscription?.cancel();
      if (_recordDuration < 1) {
        await _audioRecorder.stop();
        widget.onCancel();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording too short to send.')));
        return;
      }
      final path = await _audioRecorder.stop();
      if (path != null) {
        widget.onSend(path);
      } else {
        widget.onCancel();
      }
    } catch (e) {
      debugPrint('Error stopAndSend: $e');
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _durationTimer?.cancel();
      _amplitudeSubscription?.cancel();
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Error cancelRecording: $e');
    } finally {
      widget.onCancel();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
  
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.grey), onPressed: _cancelRecording),
            IconButton(icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: AppColors.orange), onPressed: _togglePause),
            const SizedBox(width: 8),
            Expanded(
              child: _isRecording
                  ? _isPaused
                      ? const Center(child: Text('Paused', style: TextStyle(color: AppColors.grey)))
                      : CustomPaint(
                          size: const Size(double.infinity, 30),
                          painter: WaveformPainter(
                            amplitudes: _amplitudes,
                            color: AppColors.orange,
                          ),
                        )
                  : const SizedBox(),
            ),
            const SizedBox(width: 8),
            Text(_formatDuration(_recordDuration), style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _stopAndSend,
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.orange,
                child: Icon(Icons.send, color: AppColors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  WaveformPainter({required this.amplitudes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const double barSpacing = 5.0;
    final int maxBars = (size.width / barSpacing).floor();
    
    // Get the last `maxBars` amplitudes
    List<double> displayAmplitudes = amplitudes.length > maxBars 
        ? amplitudes.sublist(amplitudes.length - maxBars) 
        : amplitudes;

    double startX = size.width - (displayAmplitudes.length * barSpacing);
    if (startX < 0) startX = 0;

    for (int i = 0; i < displayAmplitudes.length; i++) {
      final double x = startX + (i * barSpacing);
      final double barHeight = displayAmplitudes[i] * size.height;
      final double yTop = (size.height - barHeight) / 2;
      final double yBottom = yTop + barHeight;

      canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return true; // We want it to animate smoothly on every update
  }
}

