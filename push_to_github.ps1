# PowerShell script to push code to GitHub
# Repository: https://github.com/aryanshetty-creator/Qurom_kafka.git

Write-Host "🚀 Pushing Kafka CDC Project to GitHub" -ForegroundColor Green
Write-Host "=" * 50

# Step 1: Initialize git if not already done
if (-not (Test-Path .git)) {
    Write-Host "📦 Initializing Git repository..." -ForegroundColor Yellow
    git init
} else {
    Write-Host "✅ Git repository already initialized" -ForegroundColor Green
}

# Step 2: Add remote
Write-Host "🔗 Adding remote repository..." -ForegroundColor Yellow
git remote remove origin 2>$null  # Remove if exists
git remote add origin https://github.com/aryanshetty-creator/Qurom_kafka.git

# Step 3: Create .gitignore
Write-Host "📝 Creating .gitignore..." -ForegroundColor Yellow
@"
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
*.egg-info/

# Docker
.env

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
"@ | Out-File -FilePath .gitignore -Encoding utf8

# Step 4: Add all files
Write-Host "➕ Adding files to git..." -ForegroundColor Yellow
git add .

# Step 5: Commit
Write-Host "💾 Creating commit..." -ForegroundColor Yellow
git commit -m "Initial commit: Kafka CDC setup with SQL Server and Debezium

- Complete Docker Compose configuration
- SQL Server with CDC enabled
- Debezium Connect for CDC streaming
- Kafka UI for management
- Documentation and guides
- Test scripts"

# Step 6: Push to GitHub
Write-Host "⬆️  Pushing to GitHub..." -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  You may need to authenticate with GitHub" -ForegroundColor Cyan
Write-Host ""

git branch -M main
git push -u origin main

Write-Host ""
Write-Host "✅ Done! Check your repository at:" -ForegroundColor Green
Write-Host "   https://github.com/aryanshetty-creator/Qurom_kafka" -ForegroundColor Cyan