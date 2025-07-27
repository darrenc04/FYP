import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fyp_app/success.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:flutter_spinkit/flutter_spinkit.dart';

// should store in .exe file
const String faceppApiKey = 'Pc73g9Dys0MQfAcTJGUmCRhcYTNfHU9B';
const String faceppApiSecret = '0jvuzfqPhqvT9TDy4_z31iGIjzK7t9Y_';

class FaceUnlockPage extends StatefulWidget {
  const FaceUnlockPage({super.key});

  @override
  State<FaceUnlockPage> createState() => _FaceUnlockPageState();
}

class _FaceUnlockPageState extends State<FaceUnlockPage> {
  CameraController? _controller;
  bool _processing = false;
  String? _error;
  String? _referenceFaceToken;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadReferenceToken();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      final controller = CameraController(frontCamera, ResolutionPreset.low);
      await controller.initialize();
      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Camera error: $e";
      });
    }
  }

  Future<String> _getReferenceTokenPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, 'reference_face_token.txt');
  }

  Future<void> _saveReferenceToken(String token) async {
    final refPath = await _getReferenceTokenPath();
    await File(refPath).writeAsString(token);
    setState(() {
      _referenceFaceToken = token;
    });
  }

  Future<void> _loadReferenceToken() async {
    final refPath = await _getReferenceTokenPath();
    final file = File(refPath);
    if (await file.exists()) {
      final token = await file.readAsString();
      setState(() {
        _referenceFaceToken = token;
      });
    }
  }

  Future<void> _clearReferenceFace() async {
    final refPath = await _getReferenceTokenPath();
    final file = File(refPath);
    if (await file.exists()) {
      await file.delete();
    }
    setState(() {
      _referenceFaceToken = null;
      _error = null;
    });
  }

  Future<String?> _detectFaceToken(File imageFile) async {
    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/detect');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = faceppApiKey
      ..fields['api_secret'] = faceppApiSecret
      ..files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );
    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    final jsonResp = json.decode(respStr);
    if (jsonResp['faces'] != null && jsonResp['faces'].isNotEmpty) {
      return jsonResp['faces'][0]['face_token'];
    }
    return null;
  }

  Future<bool> _compareFaceTokens(String token1, String token2) async {
    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/compare');
    final response = await http.post(
      uri,
      body: {
        'api_key': faceppApiKey,
        'api_secret': faceppApiSecret,
        'face_token1': token1,
        'face_token2': token2,
      },
    );
    final jsonResp = json.decode(response.body);
    // Face++ recommends a threshold of 70-80 for 1:1 verification
    final confidence = jsonResp['confidence'] ?? 0.0;
    final threshold = jsonResp['thresholds']?['1e-3'] ?? 80.0;
    return confidence >= threshold;
  }

  Future<void> _saveReferenceFace() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final file = await _controller!.takePicture();
      final token = await _detectFaceToken(File(file.path));
      if (token != null) {
        await _saveReferenceToken(token);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reference face registered!')),
        );
      } else {
        setState(() {
          _error = "No face detected. Try again.";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
    }
    setState(() {
      _processing = false;
    });
  }

  Future<void> _compareFace() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_referenceFaceToken == null) {
      setState(() {
        _error = "No reference face found. Please register first.";
      });
      return;
    }
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final newPic = await _controller!.takePicture();
      final newToken = await _detectFaceToken(File(newPic.path));
      if (newToken == null) {
        setState(() {
          _error = "No face detected. Try again.";
        });
        setState(() {
          _processing = false;
        });
        return;
      }
      final isMatch = await _compareFaceTokens(_referenceFaceToken!, newToken);
      if (isMatch) {
        if (!mounted) return;
        await _controller?.dispose();
        _controller = null;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuccessPage()),
        );
      } else {
        setState(() {
          _error = "Face does not match reference. Try again.";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
    }
    setState(() {
      _processing = false;
    });
  }

  Future<void> _confirmAndDeleteReferenceFace() async {
    final TextEditingController pinController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Enter PIN to Confirm'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (pinController.text == '0000') {
                    Navigator.pop(context, true);
                  } else {
                    setState(() {
                      errorText = 'Incorrect PIN';
                    });
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      await _clearReferenceFace();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registered face deleted.')));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCameraReady =
        _controller != null && _controller!.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text("Face Unlock"),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Face Unlock',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent[700],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _referenceFaceToken == null
                      ? 'Register your face for secure access'
                      : 'Align your face and tap "Unlock with Face"',
                  style: TextStyle(fontSize: 16, color: Colors.blueGrey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Camera preview in a card
                Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      color: Colors.black,
                      width: 260,
                      height: 340,
                      child: isCameraReady
                          ? CameraPreview(_controller!)
                          : const Center(
                              child: SpinKitFadingCircle(
                                // Use a nice loading spinner
                                color: Colors.blueAccent,
                                size: 48,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 10),
                if (_referenceFaceToken == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _processing ? null : _saveReferenceFace,
                      icon: const Icon(Icons.camera_enhance, size: 28),
                      label: _processing
                          ? const SpinKitThreeBounce(
                              color: Colors.white,
                              size: 22,
                            )
                          : const Text(
                              "Register Face",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                if (_referenceFaceToken != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _processing ? null : _compareFace,
                      icon: const Icon(Icons.lock_open, size: 28),
                      label: _processing
                          ? const SpinKitThreeBounce(
                              color: Colors.white,
                              size: 22,
                            )
                          : const Text(
                              "Unlock with Face",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _processing
                          ? null
                          : _confirmAndDeleteReferenceFace,
                      icon: const Icon(Icons.delete_forever, size: 28),
                      label: const Text(
                        "Clear Registered Face",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
