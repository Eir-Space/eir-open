#!/bin/bash

# Setup script for Health.md Standard Repository
# This script initializes the GitHub repository and sets up GitHub Pages

echo "🏥 Setting up Health.md Standard Repository..."

# Check if we're in the right directory
if [ ! -f "README.md" ]; then
    echo "❌ Error: Please run this script from the health-md-standard directory"
    exit 1
fi

# Initialize git repository if not already done
if [ ! -d ".git" ]; then
    echo "📝 Initializing git repository..."
    git init
    git branch -M main
fi

# Create .gitignore if it doesn't exist
if [ ! -f ".gitignore" ]; then
    echo "📄 Creating .gitignore..."
    cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
pip-wheel-metadata/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Logs
*.log

# Test coverage
.coverage
.pytest_cache/
htmlcov/

# Documentation builds
docs/_build/

# Jupyter Notebook
.ipynb_checkpoints

# Environment variables (except examples)
.env
!.env.example
EOF
fi

# Stage all files
echo "📦 Staging files for initial commit..."
git add .

# Check if this is the initial commit
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "📝 Making commit..."
    git commit -m "Update Health.md standard with latest changes"
else
    echo "📝 Making initial commit..."
    git commit -m "Initial commit: Health.md open standard for LLM-optimized healthcare data

- Complete specification v1.0
- Python parser library
- GitHub Pages website
- OpenClaw skill integration
- Examples and documentation
- Privacy-first design"
fi

echo ""
echo "🚀 Repository setup complete!"
echo ""
echo "Next steps:"
echo "1. Create a GitHub repository:"
echo "   - Go to https://github.com/BirgerMoell"
echo "   - Click 'New repository'"
echo "   - Name: health-md-standard"
echo "   - Description: Open standard for LLM-optimized healthcare data"
echo "   - Make it public"
echo "   - Don't initialize with README (we have one)"
echo ""
echo "2. Push to GitHub:"
echo "   git remote add origin https://github.com/BirgerMoell/health-md-standard.git"
echo "   git push -u origin main"
echo ""
echo "3. Enable GitHub Pages:"
echo "   - Go to repository Settings"
echo "   - Scroll to 'Pages' section"
echo "   - Source: 'Deploy from a branch'"
echo "   - Branch: 'main'"
echo "   - Folder: '/docs'"
echo "   - Save"
echo ""
echo "4. Your website will be available at:"
echo "   https://birgermoell.github.io/health-md-standard/"
echo ""
echo "5. Publish Python package (optional):"
echo "   cd parser"
echo "   python setup.py sdist bdist_wheel"
echo "   twine upload dist/*"
echo ""
echo "🏥 Health.md Standard is ready to change healthcare data! 💙"