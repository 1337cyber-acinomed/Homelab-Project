<!-- Converted from Word document: Project_Polaris_Forgejo_Git_Reference.docx -->

# Project Polaris - Forgejo Git Command Reference

Purpose: Quick reference for maintaining the Project Polaris Forgejo repository from either the Windows workstation or Docker01 over Tailscale.  
  
**Docker01 Tailscale IP:** 100.64.0.13  
**Windows Laptop Tailscale IP:** 100.64.0.14

## 1. Clone the Repository (first time)

### SSH

git clone ssh://git@100.64.0.13:2222/\<username\>/\<repo\>.git

### HTTPS

git clone https://100.64.0.13/\<username\>/\<repo\>.git

## 2. Verify Current Status

### Status

git status

### Current Branch

git branch

### Remote

git remote -v

### Recent History

git log --oneline --graph --decorate -10

## 3. Pull Latest Changes

### Update local repository

git pull origin main

## 4. Stage Changes

### Single file

git add \<filename\>

### Entire directory

git add .

### Interactive

git add -p

## 5. Commit Changes

### Commit

git commit -m "Describe the change"

## 6. Push Changes

### Push

git push origin main

## 7. Typical Workflow

### Workflow

git pull origin main  
git status  
git add .  
git commit -m "Meaningful message"  
git push origin main

## 8. Update Docker01 from Windows Changes

### On Docker01

git pull origin main

## 9. Update Windows from Docker01 Changes

### On Windows

git pull origin main

## 10. Branches

### Create

git checkout -b feature-name

### Switch

git checkout main

### Merge

git merge feature-name

### Delete

git branch -d feature-name

## 11. Undo Operations

### Unstage

git restore --staged \<file\>

### Discard local file

git restore \<file\>

### Discard all local changes

git reset --hard HEAD

### View differences

git diff

## 12. SSH Connectivity

### Test SSH

ssh -T git@100.64.0.13 -p 2222

### Ping Tailscale

ping 100.64.0.13

## 13. Good Commit Message Examples

### 

git commit -m "Update Project Polaris roadmap to v3.2"

### 

git commit -m "Synchronize DNS registry"

### 

git commit -m "Add Backup Policy documentation"

### 

git commit -m "Refine Northstar architecture"

### 

git commit -m "Update maintenance backlog after Phase 2A"

## 14. Recommended Daily Workflow

1\. Pull latest changes before editing.  
2. Make documentation updates.  
3. Run git status.  
4. Stage with git add .  
5. Commit with a descriptive message.  
6. Push to Forgejo.  
7. On the other system, run git pull origin main before continuing work.  
  
This workflow prevents divergence and keeps Windows and Docker01 synchronized.
