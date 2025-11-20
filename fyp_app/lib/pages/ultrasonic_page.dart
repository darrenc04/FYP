import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_verification_page.dart';

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
    with TickerProviderStateMixin {
  final AudioRecorder audioRecorder = AudioRecorder();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  bool isRecording = false;
  bool isDetecting = false;
  bool attendanceMarked = false;
  String? detectionMessage;
  double? dominantFrequency;

  int targetFrequency = -1;
  Timestamp? _frequencyGeneratedAt;
  bool _loadingFrequency = true;
  String? _lecturerRole;

  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  Timer? _detectionTimer;
  int _sampleRate = 44100;
  int _lastFileSize = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Animation controllers for sound bars
  late List<AnimationController> _barControllers;
  late List<Animation<double>> _barAnimations;

  // Store current bar heights based on audio amplitude
  List<double> _barHeights = [0.3, 0.5, 0.8, 0.6, 0.4];
  Timer? _barAnimationTimer;

  @override
  void initState() {
    super.initState();
    _subscribeToSessionUpdates();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize 5 sound bar animations
    _barControllers = List.generate(
      5,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    _barAnimations = _barControllers.asMap().entries.map((entry) {
      return Tween<double>(
        begin: 0.3,
        end: _barHeights[entry.key],
      ).animate(CurvedAnimation(parent: entry.value, curve: Curves.easeInOut));
    }).toList();
  }

  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Unique Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? '';
      }
    } catch (e) {
      print('Error getting device ID: $e');
    }
    return '';
  }

  void _startBarAnimations() {
    // Start continuous random animation to simulate audio response
    _barAnimationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!isDetecting) {
        timer.cancel();
        return;
      }

      _updateBarHeights();
    });
  }

  void _updateBarHeights() {
    if (!mounted || !isDetecting) return;

    setState(() {
      for (int i = 0; i < 5; i++) {
        // Generate smooth random heights with variation
        double targetHeight = 0.2 + (math.Random().nextDouble() * 0.8);

        // Add some correlation between adjacent bars for smoother look
        if (i > 0) {
          targetHeight = (_barHeights[i - 1] + targetHeight) / 2;
        }

        _barHeights[i] = targetHeight;

        // Animate to new height
        _barAnimations[i] =
            Tween<double>(
              begin: _barAnimations[i].value,
              end: targetHeight,
            ).animate(
              CurvedAnimation(
                parent: _barControllers[i],
                curve: Curves.easeInOut,
              ),
            );

        _barControllers[i].forward(from: 0);
      }
    });
  }

  void _updateBarHeightsFromAudio(List<double> audioData) {
    if (!mounted || !isDetecting || audioData.isEmpty) return;

    // Calculate amplitude for each bar (divide audio into 5 frequency bands)
    int samplesPerBar = audioData.length ~/ 5;

    for (int i = 0; i < 5; i++) {
      int start = i * samplesPerBar;
      int end = math.min((i + 1) * samplesPerBar, audioData.length);

      if (start >= audioData.length) break;

      // Calculate RMS amplitude for this frequency band
      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += audioData[j] * audioData[j];
      }
      double rms = math.sqrt(sum / (end - start));

      // Normalize and clamp between 0.2 and 1.0
      double normalizedHeight = (rms * 10).clamp(0.2, 1.0);

      // Smooth the transition
      _barHeights[i] = (_barHeights[i] * 0.7) + (normalizedHeight * 0.3);
    }

    // Update animations
    setState(() {
      for (int i = 0; i < 5; i++) {
        _barAnimations[i] =
            Tween<double>(
              begin: _barAnimations[i].value,
              end: _barHeights[i],
            ).animate(
              CurvedAnimation(
                parent: _barControllers[i],
                curve: Curves.easeOut,
              ),
            );

        _barControllers[i].forward(from: 0);
      }
    });
  }

  void _stopBarAnimations() {
    _barAnimationTimer?.cancel();
    for (var controller in _barControllers) {
      controller.stop();
      controller.reset();
    }
    setState(() {
      _barHeights = [0.3, 0.3, 0.3, 0.3, 0.3];
    });
  }

  void _subscribeToSessionUpdates() {
    _sessionSubscription = FirebaseFirestore.instance
        .collection('Sessions')
        .doc(widget.sessionId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && mounted) {
              final data = snapshot.data();
              final frequency = data?['targetFrequency'] ?? -1;
              final generatedAt = data?['frequencyGeneratedAt'] as Timestamp?;
              final sessionType = data?['sessionsType'] ?? 'Lecturer';

              setState(() {
                targetFrequency = frequency is int
                    ? frequency
                    : (frequency as num).toInt();
                _frequencyGeneratedAt = generatedAt;
                _lecturerRole = sessionType == 'Lecture Class'
                    ? 'Lecturer'
                    : 'Tutor';
                _loadingFrequency = false;
              });
            } else if (mounted) {
              setState(() {
                _loadingFrequency = false;
              });
            }
          },
          onError: (e) {
            debugPrint('Error listening to session updates: $e');
            if (mounted) {
              setState(() {
                _loadingFrequency = false;
              });
            }
          },
        );
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _detectionTimer?.cancel();
    _barAnimationTimer?.cancel();
    audioRecorder.dispose();
    _pulseController.dispose();
    for (var controller in _barControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await audioRecorder.hasPermission()) {
      _showError('Microphone permission required');
      return;
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

      setState(() {
        isRecording = true;
        isDetecting = true;
        dominantFrequency = null;
        detectionMessage = null;
        _lastFileSize = 0;
        attendanceMarked = false;
      });

      _startBarAnimations();
      _startFrequencyDetection(filePath);
    } catch (e) {
      _showError('Failed to start recording: $e');
      await audioRecorder.stop();
      _stopBarAnimations();
      setState(() {
        isRecording = false;
        isDetecting = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    _detectionTimer?.cancel();
    await audioRecorder.stop();
    _stopBarAnimations();
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

            _updateBarHeightsFromAudio(recentAudio);

            final detectedFrequency = _performFFTAnalysis(recentAudio);

            if (detectedFrequency > 0) {
              setState(() {
                dominantFrequency = detectedFrequency;
              });

              // CHANGE THIS: Reduce tolerance from 100 Hz to 50 Hz
              // With 100Hz steps (e.g. 18000, 18100), a 30-50Hz tolerance prevents overlap.
              const tolerance = 50;

              // Validate timestamp (Anti-Replay)
              bool isFresh = false;
              if (_frequencyGeneratedAt != null) {
                final now = DateTime.now();
                final generatedTime = _frequencyGeneratedAt!.toDate();
                // Allow up to 15 seconds delay (broadcasts every 7s)
                if (now.difference(generatedTime).inSeconds < 15) {
                  isFresh = true;
                }
              }

              if (isFresh &&
                  (detectedFrequency - targetFrequency).abs() < tolerance) {
                timer.cancel();
                await _stopRecording();

                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceVerificationPage(
                        sessionId: widget.sessionId,
                        sessionName: widget.sessionName,
                        detectedFrequency: detectedFrequency,
                      ),
                    ),
                  );
                }
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
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

    // TIGHTENED: Reduce search bandwidth from 50 Hz to 30 Hz
    const double searchBandwidth = 30.0;

    int targetIndex = (targetFrequency / frequencyResolution).round();
    int bandwidthSamples = (searchBandwidth / frequencyResolution).ceil();

    int minSearchIndex = math.max(0, targetIndex - bandwidthSamples);
    int maxSearchIndex = math.min(
      magnitude.length - 1,
      targetIndex + bandwidthSamples,
    );

    // CALCULATE NOISE FLOOR: Find average magnitude outside target band
    double noiseFloorSum = 0;
    int noiseFloorCount = 0;

    // Sample frequencies far from target (at least 500 Hz away)
    int noiseMargin = (500 / frequencyResolution).ceil();
    int noiseStartIndex = math.max(minSearchIndex ~/ 4, 0);
    int noiseEndIndex = math.max(0, minSearchIndex - noiseMargin);

    for (int i = noiseStartIndex; i < noiseEndIndex; i++) {
      noiseFloorSum += magnitude[i];
      noiseFloorCount++;
    }

    // Also check high frequency range
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

    // INCREASED: Require much stronger signal to avoid false positives
    const double minimumMagnitudeThreshold = 1.5;

    // SIGNAL-TO-NOISE RATIO: Must be at least 10x above noise floor
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

    // TIGHTENED: Reduce final tolerance from 50 Hz to 30 Hz
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
        child: _loadingFrequency
            ? const Center(child: CircularProgressIndicator())
            : Center(
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
                        // Animated sound bars with dynamic heights
                        SizedBox(
                          height: 30,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(5, (index) {
                              return AnimatedBuilder(
                                animation: _barAnimations[index],
                                builder: (context, child) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    width: 4,
                                    height: 30 * _barAnimations[index].value,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                },
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Taking Attendance',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        if (dominantFrequency != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Detecting: ${dominantFrequency!.toStringAsFixed(0)} Hz',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
