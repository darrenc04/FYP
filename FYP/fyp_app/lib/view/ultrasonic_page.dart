import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/ultrasonic_controller.dart';
import 'device_verification_page.dart';

class UltrasonicPage extends StatefulWidget {
  final String sessionId;
  final String sessionName;

  const UltrasonicPage({
    super.key,
    required this.sessionId,
    required this.sessionName,
  });

  @override
  State<UltrasonicPage> createState() => _UltrasonicPageState();
}

class _UltrasonicPageState extends State<UltrasonicPage>
    with TickerProviderStateMixin {
  // Controller - handles all business logic
  late UltrasonicController _controller;

  // UI State
  bool isRecording = false;
  bool isDetecting = false;
  bool attendanceMarked = false;
  double? dominantFrequency;
  int targetFrequency = -1;
  // ignore: unused_field
  Timestamp? _frequencyGeneratedAt;
  bool _loadingFrequency = true;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late List<AnimationController> _barControllers;
  late List<Animation<double>> _barAnimations;

  // Sound bar heights
  List<double> _barHeights = [0.3, 0.5, 0.8, 0.6, 0.4];
  Timer? _barAnimationTimer;

  // ignore: unused_field
  String? _recordingFilePath;

  @override
  void initState() {
    super.initState();

    // Initialize controller
    _controller = UltrasonicController(
      sessionId: widget.sessionId,
      sessionName: widget.sessionName,
    );

    // Subscribe to frequency updates
    _controller.subscribeToSessionUpdates((targetFreq, generatedAt, loading) {
      if (mounted) {
        setState(() {
          targetFrequency = targetFreq;
          _frequencyGeneratedAt = generatedAt;
          _loadingFrequency = loading;
        });
      }
    });

    // Initialize animations
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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

  @override
  void dispose() {
    _barAnimationTimer?.cancel();
    for (var controller in _barControllers) {
      controller.dispose();
    }
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // UI Event Handlers
  Future<void> _startRecording() async {
    final filePath = await _controller.startRecording();

    if (filePath == null) {
      _showError('Microphone permission required');
      return;
    }

    setState(() {
      isRecording = true;
      isDetecting = true;
      dominantFrequency = null;
      attendanceMarked = false;
      _recordingFilePath = filePath;
    });

    _startBarAnimations();

    // Start frequency detection via controller
    _controller.startFrequencyDetection(
      filePath: filePath,
      onFrequencyDetected: (frequency) {
        if (mounted) {
          setState(() {
            dominantFrequency = frequency;
          });
        }
      },
      onAudioData: (audioData) {
        _updateBarHeightsFromAudio(audioData);
      },
      onSuccess: () async {
        debugPrint("🎯 onSuccess called - stopping recording and navigating");
        await _stopRecording();

        if (mounted) {
          debugPrint(
            "🚀 Navigating to DeviceVerificationPage with frequency: $dominantFrequency",
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceVerificationPage(
                sessionId: widget.sessionId,
                sessionName: widget.sessionName,
                detectedFrequency: dominantFrequency,
              ),
            ),
          );
        } else {
          debugPrint("⚠️ Widget not mounted, cannot navigate");
        }
      },
    );
  }

  Future<void> _stopRecording() async {
    await _controller.stopRecording();
    _stopBarAnimations();
    if (mounted) {
      setState(() {
        isRecording = false;
        isDetecting = false;
      });
    }
  }

  // Animation Methods (UI only)
  void _startBarAnimations() {
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
        double targetHeight = 0.2 + (math.Random().nextDouble() * 0.8);

        if (i > 0) {
          targetHeight = (_barHeights[i - 1] + targetHeight) / 2;
        }

        _barHeights[i] = targetHeight;

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

    int samplesPerBar = audioData.length ~/ 5;

    for (int i = 0; i < 5; i++) {
      int start = i * samplesPerBar;
      int end = math.min((i + 1) * samplesPerBar, audioData.length);

      if (start >= audioData.length) break;

      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += audioData[j] * audioData[j];
      }
      double rms = math.sqrt(sum / (end - start));
      double normalizedHeight = (rms * 10).clamp(0.2, 1.0);

      _barHeights[i] = (_barHeights[i] * 0.7) + (normalizedHeight * 0.3);
    }

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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Build UI
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
                        // Animated sound bars
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
                        // if (dominantFrequency != null) ...[
                        //   const SizedBox(height: 12),
                        //   Text(
                        //     'Detecting: ${dominantFrequency!.toStringAsFixed(0)} Hz',
                        //     style: const TextStyle(
                        //       color: Colors.white70,
                        //       fontSize: 14,
                        //     ),
                        //   ),
                        // ],
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
