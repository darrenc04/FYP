import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Controller for ultrasonic frequency detection and attendance marking
/// Contains ALL business logic: audio recording, FFT analysis, frequency detection
class UltrasonicController {
  final String sessionId;
  final String sessionName;

  final AudioRecorder audioRecorder = AudioRecorder();
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  Timer? _detectionTimer;
  int _sampleRate = 44100;
  int _lastFileSize = 0;

  int targetFrequency = -1;
  Timestamp? _frequencyGeneratedAt;

  UltrasonicController({required this.sessionId, required this.sessionName});

  /// Subscribe to session frequency updates from Firestore
  void subscribeToSessionUpdates(
    Function(int targetFrequency, Timestamp? generatedAt, bool loading)
    callback,
  ) {
    // Get today's date in format YYYY-MM-DD
    final today = DateTime.now();
    final dateId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Listen to Sessions/{sessionId}/{dateId}/session_info
    _sessionSubscription = FirebaseFirestore.instance
        .collection('Sessions')
        .doc(sessionId)
        .collection(dateId)
        .doc('session_info')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data();
              final frequency = data?['targetFrequency'] ?? -1;
              final generatedAt = data?['frequencyGeneratedAt'] as Timestamp?;

              targetFrequency = frequency is int
                  ? frequency
                  : (frequency as num).toInt();
              _frequencyGeneratedAt = generatedAt;

              debugPrint(
                '✅ Listening to Sessions/$sessionId/$dateId/session_info - Frequency: $targetFrequency Hz',
              );
              callback(targetFrequency, generatedAt, false);
            } else {
              debugPrint(
                '⚠️ No session_info found for Sessions/$sessionId/$dateId/session_info',
              );
              callback(-1, null, false);
            }
          },
          onError: (e) {
            debugPrint('Error listening to session updates: $e');
            callback(-1, null, false);
          },
        );
  }

  /// Start audio recording
  Future<String?> startRecording() async {
    if (!await audioRecorder.hasPermission()) {
      return null; // Permission denied
    }

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'attendance_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
    final filePath = p.join(tempDir.path, fileName);

    try {
      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );

      _lastFileSize = 0;
      return filePath;
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      return null;
    }
  }

  /// Stop audio recording
  Future<void> stopRecording() async {
    debugPrint("🛑 Stopping recording and detection timer");
    _detectionTimer?.cancel();
    _detectionTimer = null;
    await audioRecorder.stop();
  }

  /// Start frequency detection loop
  void startFrequencyDetection({
    required String filePath,
    required Function(double? frequency) onFrequencyDetected,
    required Function(List<double> audioData) onAudioData,
    required Function() onSuccess,
  }) {
    _detectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
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

            onAudioData(recentAudio);

            final detectedFrequency = _performFFTAnalysis(recentAudio);

            if (detectedFrequency > 0) {
              onFrequencyDetected(detectedFrequency);

              const tolerance = 50;

              // Validate timestamp (Anti-Replay)
              bool isFresh = false;
              if (_frequencyGeneratedAt != null) {
                final now = DateTime.now();
                final generatedTime = _frequencyGeneratedAt!.toDate();
                if (now.difference(generatedTime).inSeconds < 15) {
                  isFresh = true;
                }
              }

              if (isFresh &&
                  (detectedFrequency - targetFrequency).abs() < tolerance) {
                debugPrint(
                  "✅ FREQUENCY MATCH CONFIRMED - Navigating to verification",
                );
                timer.cancel();
                _detectionTimer?.cancel();
                onSuccess();
                return;
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Detection error: $e");
      }
    });
  }

  /// Parse WAV file to extract audio data
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

  /// Parse as raw audio if WAV header parsing fails
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

  /// Perform FFT analysis on audio data
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

    const double searchBandwidth = 30.0;

    int targetIndex = (targetFrequency / frequencyResolution).round();
    int bandwidthSamples = (searchBandwidth / frequencyResolution).ceil();

    int minSearchIndex = math.max(0, targetIndex - bandwidthSamples);
    int maxSearchIndex = math.min(
      magnitude.length - 1,
      targetIndex + bandwidthSamples,
    );

    // Calculate noise floor
    double noiseFloorSum = 0;
    int noiseFloorCount = 0;

    int noiseMargin = (500 / frequencyResolution).ceil();
    int noiseStartIndex = math.max(minSearchIndex ~/ 4, 0);
    int noiseEndIndex = math.max(0, minSearchIndex - noiseMargin);

    for (int i = noiseStartIndex; i < noiseEndIndex; i++) {
      noiseFloorSum += magnitude[i];
      noiseFloorCount++;
    }

    int highNoiseStartIndex = math.min(
      magnitude.length - 1,
      maxSearchIndex + noiseMargin,
    );
    int highNoiseEndIndex = math.min(
      magnitude.length - 1,
      highNoiseStartIndex + noiseMargin,
    );

    for (
      int i = highNoiseStartIndex;
      i < highNoiseEndIndex && i < magnitude.length;
      i++
    ) {
      noiseFloorSum += magnitude[i];
      noiseFloorCount++;
    }

    double noiseFloor = noiseFloorCount > 0
        ? noiseFloorSum / noiseFloorCount
        : 0;

    double maxMagnitude = 0;
    int maxIndex = 0;

    for (int i = minSearchIndex; i <= maxSearchIndex; i++) {
      if (magnitude[i] > maxMagnitude) {
        maxMagnitude = magnitude[i];
        maxIndex = i;
      }
    }

    const double minimumMagnitudeThreshold = 1.5;
    const double minimumSNR = 10.0;
    double snr = noiseFloor > 0 ? maxMagnitude / noiseFloor : 0;

    debugPrint(
      "FFT Analysis - Target: $targetFrequency Hz, "
      "Max Magnitude: ${maxMagnitude.toStringAsFixed(4)}, "
      "Noise Floor: ${noiseFloor.toStringAsFixed(4)}, "
      "SNR: ${snr.toStringAsFixed(2)}",
    );

    if (maxMagnitude < minimumMagnitudeThreshold) {
      debugPrint(
        "REJECTED: Signal too weak (${maxMagnitude.toStringAsFixed(4)} < $minimumMagnitudeThreshold)",
      );
      return 0;
    }

    if (snr < minimumSNR) {
      debugPrint(
        "REJECTED: SNR too low (${snr.toStringAsFixed(2)} < $minimumSNR)",
      );
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

    const double finalTolerance = 30.0;
    if ((frequency - targetFrequency).abs() > finalTolerance) {
      debugPrint(
        "REJECTED: Frequency mismatch - Detected: ${frequency.toStringAsFixed(1)} Hz vs Target: $targetFrequency Hz "
        "(diff: ${(frequency - targetFrequency).abs().toStringAsFixed(1)} Hz > $finalTolerance Hz)",
      );
      return 0;
    }

    debugPrint(
      "ACCEPTED: Detected ${frequency.toStringAsFixed(1)} Hz "
      "(Target: $targetFrequency Hz, SNR: ${snr.toStringAsFixed(2)})",
    );

    return frequency;
  }

  /// Find nearest power of two
  int _nearestPowerOfTwo(int n) {
    int power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }

  /// Fast Fourier Transform
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

  /// Clean up resources
  void dispose() {
    _sessionSubscription?.cancel();
    _detectionTimer?.cancel();
    audioRecorder.dispose();
  }
}

/// Complex number class for FFT
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
