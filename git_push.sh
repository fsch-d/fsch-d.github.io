#!/bin/bash
#
# Shell script to prepare and push a local Git repository to the 'main' branch 
# of the 'origin' remote (GitHub).
#
# NOTE ON AUTHENTICATION:
# The commands below assume you have set up a secure authentication method 
# like the Git Credential Manager (GCM) or SSH keys. 
# DO NOT hardcode your Personal Access Token (PAT) directly into this file, 
# as it is a major security risk.

# Exit immediately if a command exits with a non-zero status.
set -e

# 1. Stage all changes in the current directory
echo "Staging all files..."
git add .

# 2. Commit the staged changes
echo "Committing changes with message: 'First commit'..."
git commit -m "First commit"

# 3. Push the changes and set 'origin main' as the upstream remote
# This command pushes to GitHub and handles authentication via GCM or SSH.
echo "Pushing committed changes to GitHub..."
git push -u origin main

echo "Push complete!"
