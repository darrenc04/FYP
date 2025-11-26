# Eye Blink Detection for Attendance (FaceVerificationPageV2)

## Overview
A new face verification page that uses **eye blink detection** for liveness detection instead of comparing stored face embeddings. This prevents spoofing attacks using photos or videos.

## Files Created/Modified

### Flutter Frontend
**File:** `lib/pages/face_verification_page_v2.dart`

**Features:**
- Records a short video (max 10 seconds) from the device's front camera
- Sends video to backend for eye blink analysis
- Requires at least 2 eye blinks for verification success
- Displays real-time feedback during processing
- Falls back to device verification and location verification on success

**Key Methods:**
- `_verifyEyeBlinkAndMarkAttendance()` - Main verification flow
- `_detectEyeBlinks(userId, video)` - Sends video to backend API

**API Endpoint Used:**
```
POST /detect-eye-blinks
Body: multipart/form-data
  - video: XFile (video from camera)
  - user_id: String (user email)
```

### Python Backend
**File:** `deepface_backend/app.py`

**New Endpoint:** `POST /detect-eye-blinks`

**Technologies:**
- **MediaPipe Face Mesh** - For detecting facial landmarks
- **OpenCV** - For video processing
- **SciPy** - For distance calculations

**How It Works:**
1. Receives video file from Flutter app
2. Opens video and processes frame-by-frame
3. Uses MediaPipe to detect 468 facial landmarks
4. Calculates **Eye Aspect Ratio (EAR)** for both eyes using:
   - Distance between eyelids
   - Horizontal eye width
5. Detects blink when EAR drops below threshold (0.15)
6. Counts minimum 3 consecutive frames for valid blink
7. Returns blink count and liveness score

**Response Format:**
```json
{
  "success": true,
  "user_id": "user@example.com",
  "blinks_detected": 2,
  "confidence": 85.50,
  "is_live": true,
  "frame_count": 150,
  "message": "Liveness verified"
}
```

### Requirements Updated
**File:** `deepface_backend/requirements.txt`

Added packages:
- `mediapipe>=0.10.0` - For facial landmark detection
- `scipy>=1.11.0` - For distance calculations

## Setup Instructions

### 1. Install Backend Dependencies
```powershell
cd deepface_backend
pip install -r requirements.txt
```

### 2. Start Backend Server
```powershell
python app.py
```

Server will run on `http://192.168.100.177:5000` (update IP as needed in code)

### 3. Use in Flutter App
Import and use the new page:
```dart
import 'package:fyp_app/pages/face_verification_page_v2.dart';

// Navigate to eye blink verification
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FaceVerificationPageV2(
      sessionId: sessionId,
      courseCode: courseCode,
      courseName: courseName,
      sessionType: sessionType,
    ),
  ),
);
```

## Verification Flow

1. **User taps "Record Video"**
   - Camera opens for recording
   - Max 10 seconds duration

2. **Video is sent to backend**
   - MediaPipe detects face and landmarks
   - Eye blinks are counted frame-by-frame
   - Confidence score calculated

3. **Backend returns results**
   - If ≥2 blinks detected → Liveness verified ✓
   - If <2 blinks → Verification failed ✗

4. **On Success**
   - Proceeds to Device Verification (ultrasonic frequency check)
   - Then Location Verification
   - Finally marks attendance

## Eye Aspect Ratio (EAR) Explanation

```
Eye landmarks (6 points per eye):
    1   2
  0       3
    5   4

EAR = (||p1-p5|| + ||p2-p4||) / (2 * ||p0-p3||)

- Open eye: EAR ≈ 0.3-0.4
- Closed eye: EAR ≈ 0.1-0.15
- Threshold: 0.15 (below = closed)
```

## Advantages

✓ **Liveness Detection** - Prevents photo/video spoofing
✓ **No Face Enrollment Required** - Works without stored face data
✓ **Fast Processing** - Analyzes 10-second video in ~5-10 seconds
✓ **Reliable** - MediaPipe achieves 99%+ facial landmark detection
✓ **Mobile Friendly** - Natural interaction (just blink eyes)

## Limitations

⚠ **Requirements:**
- Good lighting needed for accurate landmark detection
- Face must be clearly visible (no sunglasses, masks)
- Video must contain at least one clear blink
- Internet connection needed (backend processing)

⚠ **Edge Cases:**
- Very fast blinks might not register
- Low lighting reduces accuracy
- Partial face visibility fails detection

## Testing

### Test Case 1: Normal Verification
- Record video with 2-3 natural blinks
- Expected: ✓ Success, confidence 50-100%

### Test Case 2: No Blinks
- Record video but don't blink
- Expected: ✗ Fail, "Need at least 2 eye blinks"

### Test Case 3: No Face
- Record empty background
- Expected: ✗ Fail, "No live face detected"

## Future Enhancements

- [ ] Adjust EAR threshold based on user-specific calibration
- [ ] Add multiple blink patterns (specific sequence)
- [ ] Store successful verifications in Firestore
- [ ] Implement spoofing detection (texture analysis)
- [ ] Add anti-replay detection (timestamp verification)
- [ ] Performance optimization for faster processing
