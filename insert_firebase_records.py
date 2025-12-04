#!/usr/bin/env python3
"""
Insert random session records into Firebase using Firestore REST API.
This creates records similar to your 2025-12-04 example.
"""

import json
from datetime import datetime, timedelta
import random

# Sample session data (similar to your 2025-12-04 example)
SESSIONS_DATA = [
    {
        'sessionId': 'BMSE3014',
        'lecturerName': 'Dr. Lim Fung Ji',
        'location': {'latitude': 32.1541660, 'longitude': 101.7266751},
        'physicalLocation': 'K101',
        'sessionsName': 'Software Maintenance',
        'sessionsType': 'Tutorial',
    },
    {
        'sessionId': 'BMIT2073',
        'lecturerName': 'Dr. John Ooi',
        'location': {'latitude': 32.1600, 'longitude': 101.7300},
        'physicalLocation': 'L205',
        'sessionsName': 'Mobile Application Development',
        'sessionsType': 'Practical',
    },
    {
        'sessionId': 'BICT2083',
        'lecturerName': 'Prof. Ravi Kumar',
        'location': {'latitude': 32.1500, 'longitude': 101.7200},
        'physicalLocation': 'D101',
        'sessionsName': 'Database Design',
        'sessionsType': 'Lecture',
    },
]

def generate_records_json(num_records=10):
    """Generate JSON structure for Firebase records"""
    
    print(f"\n📝 Generating {num_records} random records...\n")
    
    today = datetime.now()
    records = []
    
    for i in range(num_records):
        # Pick random session
        session = random.choice(SESSIONS_DATA)
        session_id = session['sessionId']
        
        # Generate random date (1-30 days from now)
        days_offset = random.randint(1, 30)
        date = today + timedelta(days=days_offset)
        date_str = date.strftime('%Y-%m-%d')
        
        # Format times as ISO strings
        start_time = datetime(date.year, date.month, date.day, 12, 0, 0)
        end_time = datetime(date.year, date.month, date.day, 23, 59, 59)
        
        # Create Firestore document structure
        record = {
            'path': f'Sessions/{session_id}/{date_str}/session_info',
            'data': {
                'end_time': end_time.isoformat() + 'Z',
                'frequencyGeneratedAt': datetime.now().isoformat() + 'Z',
                'isCancelled': random.choice([True, False]),
                'lecturerName': session['lecturerName'],
                'location': session['location'],
                'physicalLocation': session['physicalLocation'],
                'sessionsName': session['sessionsName'],
                'sessionsType': session['sessionsType'],
                'start_time': start_time.isoformat() + 'Z',
                'targetFrequency': 18000 + (random.randint(0, 20) * 100),
            }
        }
        records.append(record)
    
    return records

def print_firestore_instructions(records):
    """Print step-by-step Firestore Console instructions"""
    
    print("="*70)
    print("📋 FIRESTORE CONSOLE MANUAL INSTRUCTIONS")
    print("="*70)
    print("\nFollow these steps to create each record:\n")
    
    for idx, record in enumerate(records, 1):
        path = record['path']
        data = record['data']
        cancelled_text = "🔴 CANCELLED" if data['isCancelled'] else "✅ ACTIVE"
        
        print(f"\n📌 Record {idx} {cancelled_text}")
        print(f"   Path: {path}")
        print(f"   Lecturer: {data['lecturerName']}")
        print(f"   Type: {data['sessionsType']}")
        print(f"   Frequency: {data['targetFrequency']} Hz")
        print(f"\n   Steps:")
        print(f"   1. Go to Firestore Console")
        print(f"   2. Navigate to: Sessions → {path.split('/')[1]}")
        print(f"   3. Create subcollection named: {path.split('/')[2]}")
        print(f"   4. Create document named: session_info")
        print(f"   5. Add these fields:")
        for field, value in data.items():
            if isinstance(value, dict):
                print(f"      • {field}: {json.dumps(value)}")
            else:
                print(f"      • {field}: {value}")
    
    print(f"\n{'='*70}\n")

def save_to_file(records):
    """Save records to JSON file for reference"""
    
    filename = 'firebase_records.json'
    with open(filename, 'w') as f:
        json.dump(records, f, indent=2)
    
    print(f"✓ Records saved to {filename}")
    print(f"✓ Total records: {len(records)}\n")

if __name__ == '__main__':
    num_records = 10  # Change this number for more/fewer records
    records = generate_records_json(num_records)
    print_firestore_instructions(records)
    save_to_file(records)
