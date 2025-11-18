# DeepFace Backend Server

A Flask-based REST API for face registration and verification using DeepFace library.

## Installation & Setup

### Prerequisites
- Python 3.8 or higher
- pip (Python package manager)

### Step 1: Create Virtual Environment

```bash
cd deepface_backend
python -m venv venv
```

**Activate virtual environment:**

Windows (PowerShell):
```powershell
.\venv\Scripts\Activate.ps1
```

Windows (Command Prompt):
```cmd
venv\Scripts\activate
```

macOS/Linux:
```bash
source venv/bin/activate
```

### Step 2: Install Dependencies

```bash
pip install -r requirements.txt
```

> **Note:** First time installation may take 5-10 minutes as it downloads pre-trained models (~1-2GB).

### Step 3: Run the Server

```bash
python app.py
```

Server will start on `http://localhost:5000`

## API Endpoints

### 1. Health Check
```
GET /health
```
Returns server status.

**Response:**
```json
{
  "status": "ok",
  "message": "DeepFace backend is running"
}
```

---

### 2. Register Face
```
POST /register-face
```

Register a user's face for future verification.

**Request:**
- `user_id` (form field): Unique user identifier
- `image` (file): Face image (PNG, JPG, JPEG)

**Example using cURL:**
```bash
curl -X POST http://localhost:5000/register-face \
  -F "user_id=user123@email.com" \
  -F "image=@path/to/face.jpg"
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Face registered successfully",
  "user_id": "user123@email.com",
  "embedding_size": 2048
}
```

**Response (Error):**
```json
{
  "error": "Could not extract face from image: No face detected"
}
```

---

### 3. Verify Face
```
POST /verify-face
```

Verify if a user's current face matches their registered face.

**Request:**
- `user_id` (form field): User identifier (must be previously registered)
- `image` (file): Current face image to verify

**Example using cURL:**
```bash
curl -X POST http://localhost:5000/verify-face \
  -F "user_id=user123@email.com" \
  -F "image=@path/to/current_face.jpg"
```

**Response (Match):**
```json
{
  "success": true,
  "user_id": "user123@email.com",
  "is_match": true,
  "confidence": 95.67,
  "distance": 0.1234,
  "threshold": 0.4,
  "message": "Face verified successfully"
}
```

**Response (No Match):**
```json
{
  "success": true,
  "user_id": "user123@email.com",
  "is_match": false,
  "confidence": 42.15,
  "distance": 0.8765,
  "threshold": 0.4,
  "message": "Face does not match"
}
```

---

### 4. Compare Two Faces
```
POST /compare-faces
```

Compare two face images directly without user registration.

**Request:**
- `image1` (file): First face image
- `image2` (file): Second face image

**Example using cURL:**
```bash
curl -X POST http://localhost:5000/compare-faces \
  -F "image1=@path/to/face1.jpg" \
  -F "image2=@path/to/face2.jpg"
```

**Response:**
```json
{
  "success": true,
  "is_match": true,
  "confidence": 92.45,
  "distance": 0.1555,
  "threshold": 0.4,
  "message": "Faces match"
}
```

---

### 5. Delete Face
```
DELETE /delete-face/<user_id>
```

Delete a user's registered face embedding.

**Example using cURL:**
```bash
curl -X DELETE http://localhost:5000/delete-face/user123@email.com
```

**Response:**
```json
{
  "success": true,
  "message": "Face deleted for user user123@email.com"
}
```

---

## Configuration

### Adjusting Matching Threshold

The default threshold is `0.4` for face matching. Adjust in `app.py`:

```python
threshold = 0.4  # Lower = stricter matching (0.3-0.6 recommended)
```

- **0.3-0.35**: Very strict (may have false negatives)
- **0.4-0.45**: Balanced (recommended)
- **0.5+**: Lenient (may have false positives)

### Using Different Models

Change the model in `get_face_embedding()`:

```python
embedding = DeepFace.represent(
    img_path=image_path,
    model_name='VGGFace2',  # Options: VGGFace2, ArcFace, OpenFace, DeepFace
    enforce_detection=True,
    normalization='base'
)
```

---

## Production Deployment

For production use:

1. **Store embeddings in database** (MongoDB, PostgreSQL, etc.) instead of memory
2. **Add authentication** to API endpoints
3. **Deploy on production server** (AWS EC2, Google Cloud, etc.)
4. **Use HTTPS** for encrypted communication
5. **Add rate limiting** to prevent abuse
6. **Monitor server logs** for debugging

---

## Troubleshooting

### "No face detected" error
- Ensure image has clear, front-facing face
- Image should be well-lit
- Face should occupy significant portion of image

### Slow response time
- First request downloads models (~1-2GB)
- Subsequent requests are faster
- Use GPU if available for faster processing

### Port already in use
```bash
# Change port in app.py:
app.run(host='0.0.0.0', port=5001, debug=True)  # Use 5001 instead
```

---

## License

This backend uses DeepFace library. See deepface documentation for details.
