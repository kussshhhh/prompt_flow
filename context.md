# prompt_flow - context

## what we built

automated pipeline to extract and store claude code conversation history.

## components

**extract_prompts.py** - extracts user prompts from ~/.claude/projects/ to text files
- reads all claude code jsonl conversation files
- outputs clean text files per project (cooking-prompt-flow.txt, work2.txt, etc)
- handles multiple sessions per project by combining prompts

**parse_to_db.py** - parses claude conversations directly to sqlite database
- stores prompts with metadata (project, session, timestamp)
- implements deduplication via count increment
- includes full-text search capability
- preserves original jsonl structure and timing

**update_prompts.sh** - automation script that runs both extractors
- updates text files and database
- logs all operations to prompt_sync.log

**cronjob** - runs update_prompts.sh every hour
- 0 * * * * /path/to/prompt_flow/update_prompts.sh
- survives system restarts
- keeps prompt collection current

## database schema

```sql
prompts: id, content, project_name, session_id, timestamp, count
projects: id, name, total_prompts, last_synced
prompts_fts: full-text search on content and project_name
```

## file structure

```
prompt_exports/           # text files for human reading
prompts.db               # sqlite database 
prompt_sync.log          # automation logs
.gitignore               # excludes exports and database
```

## current state

216 prompts extracted from 10 projects across multiple claude sessions.
automated collection running hourly.
ready for pattern analysis and template extraction.