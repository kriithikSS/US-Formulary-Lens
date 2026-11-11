# Phase 0 Git setup — run these in PowerShell from the project root
# (Git must be installed: https://git-scm.com/download/win)

Set-Location "c:\Users\lenovo\Downloads\US-Formulary-Lens"

git init
git add .gitignore
git add .env.example
git add README.md
git add requirements.txt
git add docker-compose.yml
git add docs\
git add etl\
git add sql\
git add dashboard\__init__.py
git add ml\__init__.py
git add tests\__init__.py

git commit -m "Phase 0: scaffold repo structure, schema DDL, docs, docker-compose"
