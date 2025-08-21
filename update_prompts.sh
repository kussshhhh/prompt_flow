#!/bin/bash
# Update prompts cronjob script
# This script updates both txt exports and SQLite database

# Change to script directory
cd "$(dirname "$0")"

# Log with timestamp
echo "$(date): Starting prompt update..." >> prompt_sync.log

# Update txt files
echo "$(date): Updating TXT exports..." >> prompt_sync.log
python3 extract_prompts.py >> prompt_sync.log 2>&1

# Update SQLite database  
echo "$(date): Updating SQLite database..." >> prompt_sync.log
python3 parse_to_db.py >> prompt_sync.log 2>&1

echo "$(date): Prompt update completed" >> prompt_sync.log
echo "---" >> prompt_sync.log