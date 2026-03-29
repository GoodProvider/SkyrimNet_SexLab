#!/usr/bin/env python3
import sys
import os
import argparse

def replace_actors_in_file(file_path, dry_run=False):
    """Replace 'actors.0' with 'actors.1' in the given file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check if replacement is needed
        if 'actors.0' in content:
            if dry_run:
                print(f"Would update: {file_path}")
            else:
                # Replace actors.0 with actors.1
                modified_content = content.replace('actors.0', '---temp---').replace("actors.1","actors.0").replace("---temp---","actors.1")
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(modified_content)
                print(f"Updated: {file_path}")
        else:
            if dry_run:
                pass  # Don't print unchanged files in dry run
            else:
                print(f"No changes needed: {file_path}")

    except Exception as e:
        print(f"Error processing {file_path}: {e}")

def main():
    parser = argparse.ArgumentParser(description="Replace 'actors.0' with 'actors.1' in files.")
    parser.add_argument('-d', '--dry-run', action='store_true', help="Print files that would be changed without modifying them.")
    args = parser.parse_args()

    # Get all files in current directory and subdirectories
    files_to_process = []
    for root, dirs, files in os.walk('.'):
        for file in files:
            files_to_process.append(os.path.join(root, file))

    if not files_to_process:
        print("No files found in the current directory.")
        return

    for file_path in files_to_process:
        replace_actors_in_file(file_path, dry_run=args.dry_run)

if __name__ == "__main__":
    main()