#!/usr/bin/env python3
"""
Extract user prompts from Claude Code conversation history.

This script reads all JSONL files from ~/.claude/projects/ and extracts
only the user prompts (not Claude's responses) into clean text files.

Output:
- Creates prompt_exports/ folder
- One .txt file per project
- Numbered files for duplicate project names (name1.txt, name2.txt)
- Only user prompts, no responses or metadata

Usage:
    python3 extract_prompts.py
"""

import json
import os
from pathlib import Path
from collections import defaultdict

def extract_prompts():
    """Extract user prompts from all Claude Code projects."""
    
    # Get all JSONL files from Claude projects
    claude_dir = Path.home() / '.claude' / 'projects'
    if not claude_dir.exists():
        print("Claude projects directory not found at ~/.claude/projects/")
        return
    
    # Create output directory
    output_dir = Path('prompt_exports')
    output_dir.mkdir(exist_ok=True)
    
    project_counts = defaultdict(int)
    total_prompts = 0
    
    for project_dir in claude_dir.iterdir():
        if not project_dir.is_dir():
            continue
        
        # Extract full project name from directory (remove -Users-username- prefix)
        if project_dir.name.startswith('-Users-'):
            # Remove -Users-username- prefix and convert remaining path
            parts = project_dir.name.split('-')[3:]  # Skip -Users-username-
            project_name = '-'.join(parts) if parts else project_dir.name
        else:
            project_name = project_dir.name
        project_counts[project_name] += 1
        
        # Get current count for this project
        current_count = project_counts[project_name]
        output_filename = f'{project_name}{current_count}.txt' if current_count > 1 else f'{project_name}.txt'
        
        prompts = []
        
        # Process all JSONL files in this project
        for jsonl_file in project_dir.glob('*.jsonl'):
            with open(jsonl_file, 'r') as f:
                for line in f:
                    try:
                        data = json.loads(line.strip())
                        # Extract user prompts only
                        if data.get('type') == 'user' and 'message' in data:
                            content = data['message'].get('content', '')
                            if isinstance(content, str) and content.strip():
                                prompts.append(content.strip())
                    except json.JSONDecodeError:
                        continue
        
        # Write prompts to file
        if prompts:
            output_path = output_dir / output_filename
            with open(output_path, 'w') as f:
                for prompt in prompts:
                    f.write(f'{prompt}\n\n')
            print(f'Exported {len(prompts)} prompts to {output_filename}')
            total_prompts += len(prompts)
        else:
            print(f'No prompts found for {project_name}')
    
    print(f'\nTotal: {total_prompts} prompts exported to prompt_exports/')

if __name__ == '__main__':
    extract_prompts()