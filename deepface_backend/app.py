import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from deepface import DeepFace
import cv2
import numpy as np
from PIL import Image
import io
import logging
from werkzeug.utils import secure_filename
import tempfile
import mediapipe as mp
from scipy.spatial import distance

app = Flask(__name__)
CORS(app)

# Configuration
UPLOAD_FOLDER = tempfile.gettempdir()
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Store reference face embeddings (in production, store in database)
face_embeddings_db = {}

def allowed_file(filename):
    """Check if file has allowed extension"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def get_face_embedding(image_path):
    """Extract face embedding using DeepFace"""
    try:
        # Extract embedding using DeepFace (Facenet512 model - more reliable)
        embedding = DeepFace.represent(
            img_path=image_path,
            model_name='Facenet512',
            enforce_detection=True,
            normalization='base'
        )
        return embedding[0]['embedding']
    except Exception as e:
        logger.error(f"Error extracting embedding: {str(e)}")
        raise ValueError(f"Could not extract face from image: {str(e)}")

def get_face_embedding_lenient(image_path):
    """Extract face embedding with lenient detection (fallback)"""
    try:
        # Try with lenient detection - allows lower confidence detections
        embedding = DeepFace.represent(
            img_path=image_path,
            model_name='Facenet512',
            enforce_detection=False,
            normalization='base'
        )
        return embedding[0]['embedding']
    except Exception as e:
        logger.error(f"Error extracting embedding (lenient): {str(e)}")
        raise ValueError(f"Could not extract face from image: {str(e)}")

def calculate_cosine_distance(embedding1, embedding2):
    """Calculate cosine distance between two embeddings"""
    a = np.array(embedding1)
    b = np.array(embedding2)
    
    # Cosine similarity
    cosine_sim = np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))
    
    # Convert to distance (0 to 2 range, where 0 is identical)
    distance = 1 - cosine_sim
    return distance

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'message': 'DeepFace backend is running'}), 200

@app.route('/register-face', methods=['POST'])
def register_face():
    """Register a user's face for verification"""
    try:
        # Get user ID from request
        user_id = request.form.get('user_id')
        if not user_id:
            return jsonify({'error': 'user_id is required'}), 400
        
        # Check if image file is in request
        if 'image' not in request.files:
            return jsonify({'error': 'No image file provided'}), 400
        
        file = request.files['image']
        
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'error': 'Invalid file type. Allowed: png, jpg, jpeg'}), 400
        
        # Save temporary file
        temp_path = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(file.filename))
        file.save(temp_path)
        
        try:
            # Extract face embedding
            embedding = get_face_embedding(temp_path)
            
            # Store embedding (in production, save to database)
            face_embeddings_db[user_id] = embedding
            
            logger.info(f"Face registered for user: {user_id}")
            
            return jsonify({
                'success': True,
                'message': 'Face registered successfully',
                'user_id': user_id,
                'embedding_size': len(embedding)
            }), 200
        
        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.remove(temp_path)
    
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        logger.error(f"Error in register_face: {str(e)}")
        return jsonify({'error': f'Registration failed: {str(e)}'}), 500

@app.route('/verify-face', methods=['POST'])
def verify_face():
    """Verify a user's face against their registered face"""
    try:
        # Get user ID from request
        user_id = request.form.get('user_id')
        if not user_id:
            return jsonify({'error': 'user_id is required'}), 400
        
        # Check if user has registered face
        if user_id not in face_embeddings_db:
            return jsonify({'error': 'User has not registered a face yet'}), 404
        
        # Check if image file is in request
        if 'image' not in request.files:
            return jsonify({'error': 'No image file provided'}), 400
        
        file = request.files['image']
        
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'error': 'Invalid file type. Allowed: png, jpg, jpeg'}), 400
        
        # Save temporary file
        temp_path = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(file.filename))
        file.save(temp_path)
        
        try:
            # Extract face embedding from provided image
            current_embedding = get_face_embedding(temp_path)
            
            # Get stored embedding
            stored_embedding = face_embeddings_db[user_id]
            
            # Calculate distance
            distance = calculate_cosine_distance(stored_embedding, current_embedding)
            
            # Threshold for face matching (lower is more strict)
            # Typically 0.4-0.6 for VGGFace2
            threshold = 0.4
            is_match = bool(distance < threshold)  # Convert to Python bool for JSON serialization
            confidence = (1 - distance) * 100  # Convert to percentage
            
            logger.info(f"Face verification for user {user_id}: distance={distance:.4f}, match={is_match}")
            
            return jsonify({
                'success': True,
                'user_id': user_id,
                'is_match': is_match,
                'confidence': round(float(confidence), 2),
                'distance': round(float(distance), 4),
                'threshold': threshold,
                'message': 'Face verified successfully' if is_match else 'Face does not match'
            }), 200
        
        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.remove(temp_path)
    
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        logger.error(f"Error in verify_face: {str(e)}")
        return jsonify({'error': f'Verification failed: {str(e)}'}), 500

@app.route('/compare-faces', methods=['POST'])
def compare_faces():
    """Compare two face images directly"""
    try:
        # Check if both image files are in request
        if 'image1' not in request.files or 'image2' not in request.files:
            return jsonify({'error': 'Both image1 and image2 files are required'}), 400
        
        file1 = request.files['image1']
        file2 = request.files['image2']
        
        if file1.filename == '' or file2.filename == '':
            return jsonify({'error': 'Both files must be selected'}), 400
        
        if not allowed_file(file1.filename) or not allowed_file(file2.filename):
            return jsonify({'error': 'Invalid file type. Allowed: png, jpg, jpeg'}), 400
        
        # Save temporary files
        temp_path1 = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(file1.filename))
        temp_path2 = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(file2.filename))
        
        file1.save(temp_path1)
        file2.save(temp_path2)
        
        try:
            # Extract embeddings
            embedding1 = get_face_embedding(temp_path1)
            embedding2 = get_face_embedding(temp_path2)
            
            # Calculate distance
            distance = calculate_cosine_distance(embedding1, embedding2)
            threshold = 0.4
            is_match = bool(distance < threshold)  # Convert to Python bool for JSON serialization
            confidence = (1 - distance) * 100
            
            return jsonify({
                'success': True,
                'is_match': is_match,
                'confidence': round(float(confidence), 2),
                'distance': round(float(distance), 4),
                'threshold': threshold,
                'message': 'Faces match' if is_match else 'Faces do not match'
            }), 200
        
        finally:
            # Clean up temporary files
            if os.path.exists(temp_path1):
                os.remove(temp_path1)
            if os.path.exists(temp_path2):
                os.remove(temp_path2)
    
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        logger.error(f"Error in compare_faces: {str(e)}")
        return jsonify({'error': f'Comparison failed: {str(e)}'}), 500

@app.route('/delete-face/<user_id>', methods=['DELETE'])
def delete_face(user_id):
    """Delete a user's registered face"""
    try:
        if user_id in face_embeddings_db:
            del face_embeddings_db[user_id]
            logger.info(f"Face deleted for user: {user_id}")
            return jsonify({
                'success': True,
                'message': f'Face deleted for user {user_id}'
            }), 200
        else:
            return jsonify({'error': 'User face not found'}), 404
    
    except Exception as e:
        logger.error(f"Error in delete_face: {str(e)}")
        return jsonify({'error': f'Deletion failed: {str(e)}'}), 500

def detect_eye_blinks(video_path):
    """Detect eye blinks in a video using MediaPipe Face Mesh"""
    try:
        # Initialize MediaPipe
        mp_face_mesh = mp.solutions.face_mesh
        face_mesh = mp_face_mesh.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        
        # Open video
        cap = cv2.VideoCapture(video_path)
        
        if not cap.isOpened():
            raise ValueError("Could not open video file")
        
        blink_count = 0
        frame_count = 0
        face_detected = False
        eye_closed_frames = 0
        EYE_CLOSED_THRESHOLD = 0.15  # Threshold for eye closure
        MIN_FRAMES_FOR_BLINK = 3  # Minimum frames to count as a blink
        
        # Eye landmark indices (for left eye and right eye)
        LEFT_EYE = [33, 160, 158, 133, 153, 144]
        RIGHT_EYE = [362, 385, 387, 263, 373, 380]
        
        def calculate_eye_ratio(eye_points):
            """Calculate eye aspect ratio"""
            # Distance between vertical eye landmarks
            vertical_1 = distance.euclidean(eye_points[1], eye_points[5])
            vertical_2 = distance.euclidean(eye_points[2], eye_points[4])
            
            # Distance between horizontal eye landmarks
            horizontal = distance.euclidean(eye_points[0], eye_points[3])
            
            # Eye Aspect Ratio
            eye_ratio = (vertical_1 + vertical_2) / (2.0 * horizontal)
            return eye_ratio
        
        while True:
            ret, frame = cap.read()
            
            if not ret:
                break
            
            frame_count += 1
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(rgb_frame)
            
            if results.multi_face_landmarks:
                face_detected = True
                face_landmarks = results.multi_face_landmarks[0]
                landmarks = [(lm.x, lm.y, lm.z) for lm in face_landmarks.landmark]
                
                # Get eye points
                left_eye = [np.array([landmarks[i][0], landmarks[i][1]]) for i in LEFT_EYE]
                right_eye = [np.array([landmarks[i][0], landmarks[i][1]]) for i in RIGHT_EYE]
                
                # Calculate eye aspect ratios
                left_eye_ratio = calculate_eye_ratio(left_eye)
                right_eye_ratio = calculate_eye_ratio(right_eye)
                
                # Average ratio
                avg_eye_ratio = (left_eye_ratio + right_eye_ratio) / 2.0
                
                # Detect blink
                if avg_eye_ratio < EYE_CLOSED_THRESHOLD:
                    eye_closed_frames += 1
                else:
                    if eye_closed_frames >= MIN_FRAMES_FOR_BLINK:
                        blink_count += 1
                    eye_closed_frames = 0
        
        cap.release()
        face_mesh.close()
        
        if not face_detected:
            return {
                'blinks_detected': 0,
                'confidence': 0.0,
                'is_live': False,
                'frame_count': frame_count,
                'error': 'No face detected in video'
            }
        
        # Calculate confidence based on number of blinks
        # More blinks = higher confidence
        confidence = min(100.0, (blink_count / 2.0) * 100) if blink_count > 0 else 0.0
        
        logger.info(f"Eye blink detection: {blink_count} blinks detected in {frame_count} frames")
        
        return {
            'blinks_detected': blink_count,
            'confidence': round(confidence, 2),
            'is_live': blink_count >= 2,  # At least 2 blinks required for liveness
            'frame_count': frame_count,
            'error': None
        }
    
    except Exception as e:
        logger.error(f"Error in detect_eye_blinks: {str(e)}")
        return {
            'blinks_detected': 0,
            'confidence': 0.0,
            'is_live': False,
            'error': str(e)
        }

@app.route('/detect-eye-blinks', methods=['POST'])
def detect_eye_blinks_endpoint():
    """Detect eye blinks in video for liveness detection"""
    try:
        # Get user ID from request
        user_id = request.form.get('user_id')
        if not user_id:
            return jsonify({'error': 'user_id is required'}), 400
        
        # Check if video file is in request
        if 'video' not in request.files:
            return jsonify({'error': 'No video file provided'}), 400
        
        file = request.files['video']
        
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        # Check allowed video formats
        ALLOWED_VIDEO_EXTENSIONS = {'mp4', 'avi', 'mov', 'mkv', 'flv', 'wmv'}
        if '.' not in file.filename or file.filename.rsplit('.', 1)[1].lower() not in ALLOWED_VIDEO_EXTENSIONS:
            return jsonify({'error': 'Invalid video format. Allowed: mp4, avi, mov, mkv, flv, wmv'}), 400
        
        # Save temporary file
        temp_path = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(file.filename))
        file.save(temp_path)
        
        try:
            # Detect eye blinks
            result = detect_eye_blinks(temp_path)
            
            if result['error']:
                return jsonify({
                    'success': False,
                    'error': result['error'],
                    **result
                }), 400
            
            logger.info(f"Eye blink detection for user {user_id}: {result['blinks_detected']} blinks")
            
            return jsonify({
                'success': True,
                'user_id': user_id,
                'blinks_detected': result['blinks_detected'],
                'confidence': result['confidence'],
                'is_live': result['is_live'],
                'frame_count': result['frame_count'],
                'message': 'Liveness verified' if result['is_live'] else 'Not enough eye blinks detected'
            }), 200
        
        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.remove(temp_path)
    
    except Exception as e:
        logger.error(f"Error in detect_eye_blinks_endpoint: {str(e)}")
        return jsonify({'error': f'Eye blink detection failed: {str(e)}'}), 500

@app.route('/verify-face-and-blinks', methods=['POST'])
def verify_face_and_blinks():
    """Verify face match AND detect eye blinks for liveness detection"""
    try:
        # Get user ID from request
        user_id = request.form.get('user_id')
        if not user_id:
            return jsonify({'error': 'user_id is required'}), 400
        
        # Check if user has registered face
        if user_id not in face_embeddings_db:
            return jsonify({'error': 'User has not registered a face yet'}), 404
        
        # Check if video file is in request
        if 'video' not in request.files:
            return jsonify({'error': 'No video file provided'}), 400
        
        file = request.files['video']
        
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        # Check allowed video formats
        ALLOWED_VIDEO_EXTENSIONS = {'mp4', 'avi', 'mov', 'mkv', 'flv', 'wmv'}
        if '.' not in file.filename or file.filename.rsplit('.', 1)[1].lower() not in ALLOWED_VIDEO_EXTENSIONS:
            return jsonify({'error': 'Invalid video format. Allowed: mp4, avi, mov, mkv, flv, wmv'}), 400
        
        # Save temporary file
        temp_path = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(file.filename))
        file.save(temp_path)
        
        try:
            # Step 1: Detect eye blinks in video
            blink_result = detect_eye_blinks(temp_path)
            
            if blink_result['error']:
                return jsonify({
                    'success': False,
                    'error': blink_result['error'],
                    'blinks_detected': 0,
                    'confidence': 0.0,
                    'is_live': False
                }), 400
            
            # Step 2: Extract best frame from video for face verification
            # Try multiple frames to find one with a clear face
            cap = cv2.VideoCapture(temp_path)
            best_frame = None
            frame_count_video = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            
            # Sample more frames: every 10% of video for better representation
            frames_to_try = []
            for i in range(0, 11):  # 0%, 10%, 20%, ..., 100%
                frame_idx = int((i / 10) * frame_count_video)
                if frame_idx < frame_count_video:
                    frames_to_try.append(frame_idx)
            
            frame_path = os.path.join(app.config['UPLOAD_FOLDER'], 'temp_frame.jpg')
            embeddings_list = []
            used_lenient_detection = False
            
            # Step 1: Try to extract embeddings from multiple frames (strict detection)
            logger.info(f"Trying to extract faces from {len(frames_to_try)} frames...")
            
            for frame_idx in frames_to_try:
                cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
                ret, frame = cap.read()
                
                if not ret or frame is None:
                    continue
                
                # Try to extract face embedding from this frame
                cv2.imwrite(frame_path, frame)
                
                try:
                    embedding = get_face_embedding(frame_path)
                    embeddings_list.append(embedding)
                    logger.debug(f"Frame {frame_idx}: Successfully extracted face (strict)")
                    if best_frame is None:
                        best_frame = frame
                except Exception as e:
                    logger.debug(f"Frame {frame_idx} failed (strict): {str(e)}")
                    continue
            
            # If strict detection got few embeddings, try lenient detection on remaining frames
            if len(embeddings_list) < 3:
                logger.info(f"Only {len(embeddings_list)} frames succeeded with strict detection, trying lenient...")
                used_lenient_detection = True
                
                for frame_idx in frames_to_try:
                    if len(embeddings_list) >= 5:  # Stop after getting 5 embeddings
                        break
                        
                    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
                    ret, frame = cap.read()
                    
                    if not ret or frame is None:
                        continue
                    
                    cv2.imwrite(frame_path, frame)
                    
                    try:
                        embedding = get_face_embedding_lenient(frame_path)
                        # Check if this embedding is not already in our list (avoid duplicates)
                        is_duplicate = False
                        for existing in embeddings_list:
                            dist = calculate_cosine_distance(embedding, existing)
                            if dist < 0.1:  # Very similar embeddings
                                is_duplicate = True
                                break
                        
                        if not is_duplicate:
                            embeddings_list.append(embedding)
                            logger.debug(f"Frame {frame_idx}: Successfully extracted face (lenient)")
                            if best_frame is None:
                                best_frame = frame
                    except Exception as e:
                        logger.debug(f"Frame {frame_idx} failed (lenient): {str(e)}")
                        continue
            
            cap.release()
            
            if len(embeddings_list) == 0 or best_frame is None:
                return jsonify({
                    'success': False,
                    'error': 'Could not detect face in any frame of the video. Please ensure your face is clearly visible.',
                    'blinks_detected': blink_result['blinks_detected'],
                    'is_live': blink_result['is_live']
                }), 400
            
            # Average the embeddings for more robust comparison
            current_embedding = np.mean(embeddings_list, axis=0)
            logger.info(f"Averaged {len(embeddings_list)} face embeddings for comparison")
            
            try:
                # Get stored embedding
                stored_embedding = face_embeddings_db[user_id]
                
                # Calculate distance
                distance = calculate_cosine_distance(stored_embedding, current_embedding)
                
                # Use adaptive threshold based on detection mode
                # Strict detection: 0.4 (FacenetNet512 standard)
                # Lenient detection: 0.6 (more lenient, lower confidence embeddings)
                threshold = 0.6 if used_lenient_detection else 0.4
                is_match = bool(distance < threshold)
                
                # Confidence: convert distance to percentage (higher is better)
                # Distance 0 = perfect match (100%), Distance 1 = no match (0%)
                face_confidence = max(0, (1 - distance) * 100)
                
                logger.info(
                    f"Face + Blink verification for user {user_id}: "
                    f"distance={distance:.4f}, threshold={threshold}, "
                    f"detection_mode={'lenient' if used_lenient_detection else 'strict'}, "
                    f"face_match={is_match}, blinks={blink_result['blinks_detected']}, "
                    f"confidence={face_confidence:.2f}%"
                )
                
                return jsonify({
                    'success': True,
                    'user_id': user_id,
                    'is_match': is_match,
                    'face_confidence': round(float(face_confidence), 2),
                    'distance': round(float(distance), 4),
                    'blinks_detected': blink_result['blinks_detected'],
                    'blink_confidence': blink_result['confidence'],
                    'is_live': blink_result['is_live'],
                    'frame_count': blink_result['frame_count'],
                    'message': 'Face and liveness verified' if (is_match and blink_result['is_live']) else 'Verification incomplete'
                }), 200
            
            finally:
                # Clean up frame file
                if os.path.exists(frame_path):
                    os.remove(frame_path)
        
        finally:
            # Clean up temporary video file
            if os.path.exists(temp_path):
                os.remove(temp_path)
    
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        logger.error(f"Error in verify_face_and_blinks: {str(e)}")
        return jsonify({'error': f'Verification failed: {str(e)}'}), 500

@app.errorhandler(413)
def too_large(e):
    """Handle file too large error"""
    return jsonify({'error': 'File is too large. Maximum size is 16MB'}), 413

if __name__ == '__main__':
    print("Starting DeepFace Backend Server...")
    print("Available endpoints:")
    print("  GET  /health - Health check")
    print("  POST /register-face - Register user face")
    print("  POST /verify-face - Verify user face")
    print("  POST /compare-faces - Compare two faces")
    print("  POST /detect-eye-blinks - Detect eye blinks for liveness detection")
    print("  POST /verify-face-and-blinks - Verify face AND detect blinks (hybrid)")
    print("  DELETE /delete-face/<user_id> - Delete user face")
    print("\nServer running on http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)
