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
        # Extract embedding using DeepFace (VGGFace2 model)
        embedding = DeepFace.represent(
            img_path=image_path,
            model_name='VGGFace2',
            enforce_detection=True,
            normalization='base'
        )
        return embedding[0]['embedding']
    except Exception as e:
        logger.error(f"Error extracting embedding: {str(e)}")
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
            is_match = distance < threshold
            confidence = (1 - distance) * 100  # Convert to percentage
            
            logger.info(f"Face verification for user {user_id}: distance={distance:.4f}, match={is_match}")
            
            return jsonify({
                'success': True,
                'user_id': user_id,
                'is_match': is_match,
                'confidence': round(confidence, 2),
                'distance': round(distance, 4),
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
            is_match = distance < threshold
            confidence = (1 - distance) * 100
            
            return jsonify({
                'success': True,
                'is_match': is_match,
                'confidence': round(confidence, 2),
                'distance': round(distance, 4),
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
    print("  DELETE /delete-face/<user_id> - Delete user face")
    print("\nServer running on http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)
