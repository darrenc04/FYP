import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MarkAttendancePage extends StatefulWidget {
  final String sessionId;
  final String sessionName;

  const MarkAttendancePage({
    super.key,
    required this.sessionId,
    required this.sessionName,
  });

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage>
    with SingleTickerProviderStateMixin {
  final AudioRecorder audioRecorder = AudioRecorder();

  bool isRecording = false;
  bool isDetecting = false;
  bool attendanceMarked = false;
  String? detectionMessage;
  double? dominantFrequency;

  // Hardcoded frequency for testing
  final int targetFrequency = 14000; // 14kHz

  Timer? _detectionTimer;
  int _sampleRate = 44100;
  int _lastFileSize = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    audioRecorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await audioRecorder.hasPermission()) {
      final Directory appDocumentDir = await getApplicationDocumentsDirectory();
      final String filePath = p.join(
        appDocumentDir.path,
        "attendance_recording.wav",
      );

      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );

      setState(() {
        isRecording = true;
        isDetecting = true;
        dominantFrequency = null;
        detectionMessage = null;
        _lastFileSize = 0;
        attendanceMarked = false;
      });

      _startFrequencyDetection(filePath);
    }
  }

  Future<void> _stopRecording() async {
    _detectionTimer?.cancel();
    await audioRecorder.stop();
    setState(() {
      isRecording = false;
      isDetecting = false;
    });
  }

  void _startFrequencyDetection(String filePath) {
    _detectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!isRecording) {
        timer.cancel();
        return;
      }

      try {
        final file = File(filePath);
        if (await file.exists()) {
          final fileSize = await file.length();

          if (fileSize <= _lastFileSize || fileSize < 50000) {
            return;
          }

          _lastFileSize = fileSize;

          final bytes = await file.readAsBytes();
          final audioData = _parseWavFile(bytes);

          if (audioData != null && audioData.length > 8000) {
            final samplesToAnalyze = math.min(audioData.length, _sampleRate);
            final recentAudio = audioData.sublist(
              audioData.length - samplesToAnalyze,
            );

            final detectedFrequency = _performFFTAnalysis(recentAudio);

            if (detectedFrequency > 0) {
              setState(() {
                dominantFrequency = detectedFrequency;
              });

              const tolerance = 100;

              if ((detectedFrequency - targetFrequency).abs() < tolerance) {
                timer.cancel();
                await _stopRecording();

                setState(() {
                  attendanceMarked = true;
                  detectionMessage = "Attendance Marked Successfully!";
                  dominantFrequency = detectedFrequency;
                });
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Detection error: $e");
      }
    });
  }

  void _dismissSuccess() {
    setState(() {
      attendanceMarked = false;
      dominantFrequency = null;
      detectionMessage = null;
    });
  }

  List<double>? _parseWavFile(Uint8List bytes) {
    try {
      if (bytes.length < 44) return null;

      String riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
      String waveHeader = String.fromCharCodes(bytes.sublist(8, 12));

      if (riffHeader != "RIFF" || waveHeader != "WAVE") {
        return _parseAsRawAudio(bytes);
      }

      int pos = 12;
      int dataOffset = -1;
      int dataSize = 0;
      bool foundFmt = false;
      int numChannels = 1;
      int bitsPerSample = 16;

      while (pos < bytes.length - 8) {
        if (pos + 4 > bytes.length) break;
        String chunkId = String.fromCharCodes(bytes.sublist(pos, pos + 4));
        pos += 4;

        if (pos + 4 > bytes.length) break;
        int chunkSize =
            bytes[pos] |
            (bytes[pos + 1] << 8) |
            (bytes[pos + 2] << 16) |
            (bytes[pos + 3] << 24);
        pos += 4;

        if (chunkId == "fmt ") {
          foundFmt = true;
          if (pos + 16 < bytes.length) {
            numChannels = bytes[pos + 2] | (bytes[pos + 3] << 8);
            _sampleRate =
                bytes[pos + 4] |
                (bytes[pos + 5] << 8) |
                (bytes[pos + 6] << 16) |
                (bytes[pos + 7] << 24);
            if (pos + 14 < bytes.length) {
              bitsPerSample = bytes[pos + 14] | (bytes[pos + 15] << 8);
            }
          }
        } else if (chunkId == "data") {
          dataOffset = pos;
          dataSize = chunkSize;
          break;
        }

        pos += chunkSize;
        if (chunkSize % 2 == 1) pos += 1;
      }

      if (dataOffset == -1) {
        if (foundFmt) {
          dataOffset = 44;
          dataSize = bytes.length - 44;
        } else {
          return _parseAsRawAudio(bytes);
        }
      }

      if (dataOffset + dataSize > bytes.length) {
        dataSize = bytes.length - dataOffset;
      }

      Uint8List audioBytes = bytes.sublist(dataOffset, dataOffset + dataSize);
      List<double> audioData = [];

      int bytesPerSample = bitsPerSample ~/ 8;
      int frameSize = numChannels * bytesPerSample;

      for (int i = 0; i < audioBytes.length - frameSize; i += frameSize) {
        int sample = audioBytes[i] | (audioBytes[i + 1] << 8);
        if (sample > 32767) sample -= 65536;
        audioData.add(sample / 32768.0);
      }

      return audioData.isNotEmpty ? audioData : null;
    } catch (e) {
      return _parseAsRawAudio(bytes);
    }
  }

  List<double>? _parseAsRawAudio(Uint8List bytes) {
    try {
      List<double> audioData = [];
      List<int> possibleOffsets = [44, 0, 128, 256];

      for (int offset in possibleOffsets) {
        if (offset >= bytes.length) continue;

        audioData.clear();
        Uint8List audioBytes = bytes.sublist(offset);

        for (int i = 0; i < audioBytes.length - 1; i += 2) {
          int sample = audioBytes[i] | (audioBytes[i + 1] << 8);
          if (sample > 32767) sample -= 65536;
          audioData.add(sample / 32768.0);
        }

        if (audioData.length > 1000) {
          double avgAmplitude =
              audioData.map((e) => e.abs()).reduce((a, b) => a + b) /
              audioData.length;
          if (avgAmplitude > 0.001) {
            _sampleRate = 44100;
            return audioData;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  double _performFFTAnalysis(List<double> audioData) {
    if (audioData.isEmpty) return 0;

    int fftSize = math.min(32768, audioData.length);
    fftSize = _nearestPowerOfTwo(fftSize);

    List<double> window = audioData.take(fftSize).toList();

    for (int i = 0; i < window.length; i++) {
      double windowValue =
          0.5 * (1 - math.cos(2 * math.pi * i / window.length));
      window[i] *= windowValue;
    }

    List<Complex> fftResult = _fft(window.map((e) => Complex(e, 0)).toList());
    List<double> magnitude = fftResult
        .take(fftSize ~/ 2)
        .map((c) => c.magnitude)
        .toList();

    double frequencyResolution = _sampleRate.toDouble() / fftSize;

    const double searchBandwidth = 100.0;

    int targetIndex = (targetFrequency / frequencyResolution).round();
    int bandwidthSamples = (searchBandwidth / frequencyResolution).ceil();

    int minSearchIndex = math.max(0, targetIndex - bandwidthSamples);
    int maxSearchIndex = math.min(
      magnitude.length - 1,
      targetIndex + bandwidthSamples,
    );

    double maxMagnitude = 0;
    int maxIndex = 0;

    for (int i = minSearchIndex; i <= maxSearchIndex; i++) {
      if (magnitude[i] > maxMagnitude) {
        maxMagnitude = magnitude[i];
        maxIndex = i;
      }
    }

    const double minimumMagnitudeThreshold = 0.3;
    if (maxMagnitude < minimumMagnitudeThreshold) {
      return 0;
    }

    double frequency = maxIndex * frequencyResolution;

    if (maxIndex > minSearchIndex && maxIndex < maxSearchIndex) {
      double alpha = magnitude[maxIndex - 1];
      double beta = magnitude[maxIndex];
      double gamma = magnitude[maxIndex + 1];

      if (beta > alpha && beta > gamma) {
        double p = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma);
        if (p.abs() < 0.5) {
          frequency = (maxIndex + p) * frequencyResolution;
        }
      }
    }

    const double finalTolerance = 150.0;
    if ((frequency - targetFrequency).abs() > finalTolerance) {
      return 0;
    }

    return frequency;
  }

  int _nearestPowerOfTwo(int n) {
    int power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }

  List<Complex> _fft(List<Complex> x) {
    int n = x.length;
    if (n <= 1) return x;

    List<Complex> even = [];
    List<Complex> odd = [];

    for (int i = 0; i < n; i++) {
      if (i % 2 == 0) {
        even.add(x[i]);
      } else {
        odd.add(x[i]);
      }
    }

    List<Complex> evenFft = _fft(even);
    List<Complex> oddFft = _fft(odd);
    List<Complex> result = List<Complex>.filled(n, Complex(0, 0));

    for (int i = 0; i < n ~/ 2; i++) {
      Complex t =
          Complex(
            math.cos(-2 * math.pi * i / n),
            math.sin(-2 * math.pi * i / n),
          ) *
          oddFft[i];
      result[i] = evenFft[i] + t;
      result[i + n ~/ 2] = evenFft[i] - t;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF49555B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF49555B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mark Attendance',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!attendanceMarked) ...[
                const Text(
                  'Tap to take attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),

                // Microphone button
                GestureDetector(
                  onTap: isRecording ? _stopRecording : _startRecording,
                  child: ScaleTransition(
                    scale: isDetecting
                        ? _pulseAnimation
                        : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[400],
                        border: Border.all(
                          color: isDetecting
                              ? const Color(0xFF2E7DFF)
                              : Colors.grey[300]!,
                          width: 4,
                        ),
                        boxShadow: isDetecting
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2E7DFF,
                                  ).withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        Icons.headset,
                        size: 80,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                if (isDetecting) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Taking Attendance',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  if (dominantFrequency != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Detecting: ${dominantFrequency!.toStringAsFixed(0)} Hz',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ],
              ] else ...[
                // Success state
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 100,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Attendance Marked\nSuccessfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                // OK Button
                ElevatedButton(
                  onPressed: _dismissSuccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF49555B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class Complex {
  final double real;
  final double imaginary;

  Complex(this.real, this.imaginary);

  Complex operator +(Complex other) {
    return Complex(real + other.real, imaginary + other.imaginary);
  }

  Complex operator -(Complex other) {
    return Complex(real - other.real, imaginary - other.imaginary);
  }

  Complex operator *(Complex other) {
    return Complex(
      real * other.real - imaginary * other.imaginary,
      real * other.imaginary + imaginary * other.real,
    );
  }

  double get magnitude => math.sqrt(real * real + imaginary * imaginary);
}
