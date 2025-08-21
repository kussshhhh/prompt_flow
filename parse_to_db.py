#!/usr/bin/env python3
"""
Parse Claude Code conversation history directly to SQLite database.

This script reads JSONL files from ~/.claude/projects/ and stores
user prompts in a SQLite database with deduplication (count increments).

Usage:
    python3 parse_to_db.py
"""

import json
import sqlite3
import hashlib
from pathlib import Path
from datetime import datetime
from collections import defaultdict

def init_database(db_path):
    """Initialize SQLite database with schema."""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Create tables
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS prompts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            project_name TEXT NOT NULL,
            session_id TEXT NOT NULL,
            timestamp DATETIME NOT NULL,
            count INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            total_prompts INTEGER DEFAULT 0,
            last_synced DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Create indexes
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_prompts_project ON prompts(project_name)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_prompts_timestamp ON prompts(timestamp)')
    
    # Create FTS table
    cursor.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS prompts_fts USING fts5(content, project_name)
    ''')
    
    conn.commit()
    return conn

def get_project_name(project_dir_name):
    """Extract project name from Claude directory name."""
    if project_dir_name.startswith('-Users-'):
        # Remove -Users-username- prefix and convert remaining path
        parts = project_dir_name.split('-')[3:]  # Skip -Users-username-
        return '-'.join(parts) if parts else project_dir_name
    return project_dir_name

def upsert_prompt(cursor, content, project_name, session_id, timestamp):
    """Insert new prompt or increment count if exists."""
    # Check if prompt already exists
    cursor.execute('''
        SELECT id, count FROM prompts 
        WHERE content = ? AND project_name = ?
    ''', (content, project_name))
    
    existing = cursor.fetchone()
    
    if existing:
        # Increment count
        prompt_id, current_count = existing
        cursor.execute('''
            UPDATE prompts 
            SET count = count + 1, timestamp = ?
            WHERE id = ?
        ''', (timestamp, prompt_id))
        return prompt_id, current_count + 1
    else:
        # Insert new prompt
        cursor.execute('''
            INSERT INTO prompts (content, project_name, session_id, timestamp, count)
            VALUES (?, ?, ?, ?, 1)
        ''', (content, project_name, session_id, timestamp))
        
        # Insert into FTS
        cursor.execute('''
            INSERT INTO prompts_fts (content, project_name)
            VALUES (?, ?)
        ''', (content, project_name))
        
        return cursor.lastrowid, 1

def update_project_stats(cursor, project_name, total_prompts):
    """Update project statistics."""
    cursor.execute('''
        INSERT OR REPLACE INTO projects (name, total_prompts, last_synced)
        VALUES (?, ?, ?)
    ''', (project_name, total_prompts, datetime.now()))

def parse_to_database():
    """Main function to parse all Claude projects to database."""
    claude_dir = Path.home() / '.claude' / 'projects'
    if not claude_dir.exists():
        print("Claude projects directory not found at ~/.claude/projects/")
        return
    
    # Initialize database
    db_path = 'prompts.db'
    conn = init_database(db_path)
    cursor = conn.cursor()
    
    project_stats = defaultdict(int)
    total_processed = 0
    
    for project_dir in claude_dir.iterdir():
        if not project_dir.is_dir():
            continue
        
        project_name = get_project_name(project_dir.name)
        project_prompts = 0
        
        # Process all JSONL files in this project
        for jsonl_file in project_dir.glob('*.jsonl'):
            session_id = jsonl_file.stem  # filename without extension
            
            with open(jsonl_file, 'r') as f:
                for line in f:
                    try:
                        data = json.loads(line.strip())
                        
                        # Extract user prompts only
                        if data.get('type') == 'user' and 'message' in data:
                            content = data['message'].get('content', '')
                            timestamp_str = data.get('timestamp', '')
                            
                            if isinstance(content, str) and content.strip() and timestamp_str:
                                # Parse timestamp
                                timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                                
                                # Upsert prompt
                                prompt_id, count = upsert_prompt(
                                    cursor, content.strip(), project_name, 
                                    session_id, timestamp
                                )
                                
                                project_prompts += 1
                                total_processed += 1
                                
                    except json.JSONDecodeError as e:
                        print(f"Error parsing line in {jsonl_file}: {e}")
                        continue
        
        if project_prompts > 0:
            project_stats[project_name] = project_prompts
            update_project_stats(cursor, project_name, project_prompts)
            print(f"{project_name}: {project_prompts} prompts")
    
    conn.commit()
    conn.close()
    
    print(f"\nTotal: {total_processed} prompts processed")
    print(f"Database saved to: {db_path}")

if __name__ == '__main__':
    parse_to_database()