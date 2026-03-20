#!/usr/bin/env python3
"""
GitHub Security Scanner
Сканирует код на наличие бэкдоров и подозрительных паттернов
"""

import os
import re
import sys

# Паттерны бэкдоров
BACKDOOR_PATTERNS = [
    # Скрытые сетевые подключения
    r'socket\.connect.*\d+\.\d+\.\d+\.\d+',
    r'new WebSocket\(.*\)',
    r'fetch\(.*http.*\)',
    
    # Выполнение кода
    r'eval\s*\(',
    r'Function\s*\(',
    r'setTimeout\s*\(\s*["\'].*',
    r'setInterval\s*\(\s*["\'].*',
    
    # Доступ к файловой системе (подозрительный)
    r'fs\.writeFile.*\.env',
    r'file_get_contents.*\.env',
    
    # Скрытие кода
    r'atob\s*\(',  # Base64 decode
    r'Buffer\.from.*base64',
    
    # Обход безопасности
    r'require\s*\(\s*["\']child_process["\']',
    r'spawn\s*\(',
    r'exec\s*\(',
]

# Разрешённые файлы (где паттерны допустимы)
ALLOWED_FILES = [
    'security_scanner.py',
    'zero_knowledge_encryption.dart',
    '.env.example',
]

def scan_file(filepath: str) -> list:
    """Сканирует файл на наличие бэкдоров"""
    findings = []
    
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            lines = content.split('\n')
            
            for i, line in enumerate(lines, 1):
                for pattern in BACKDOOR_PATTERNS:
                    if re.search(pattern, line, re.IGNORECASE):
                        findings.append({
                            'file': filepath,
                            'line': i,
                            'pattern': pattern,
                            'content': line.strip()[:100]
                        })
    
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
    
    return findings

def scan_directory(root_dir: str) -> list:
    """Рекурсивное сканирование директории"""
    all_findings = []
    
    # Исключаемые директории
    exclude_dirs = {
        'node_modules',
        '.git',
        'build',
        'dist',
        '__pycache__',
        '.dart_tool',
        'target',
    }
    
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Пропускаем исключённые директории
        dirnames[:] = [d for d in dirnames if d not in exclude_dirs]
        
        for filename in filenames:
            filepath = os.path.join(dirpath, filename)
            
            # Пропускаем исключённые файлы
            if any(allowed in filepath for allowed in ALLOWED_FILES):
                continue
            
            # Пропускаем бинарные файлы
            if filename.endswith(('.png', '.jpg', '.gif', '.ico', '.woff', '.ttf')):
                continue
            
            # Сканируем только код
            if filename.endswith(('.dart', '.js', '.ts', '.py', '.rs', '.json', '.yaml', '.yml')):
                findings = scan_file(filepath)
                all_findings.extend(findings)
    
    return all_findings

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    print("=" * 60)
    print("🔍 GITHUB SECURITY BACKDOOR SCAN")
    print("=" * 60)
    print(f"Scanning: {root_dir}")
    print("=" * 60)
    
    findings = scan_directory(root_dir)
    
    if findings:
        print(f"\n❌ FOUND {len(findings)} POTENTIAL BACKDOORS:\n")
        
        for finding in findings:
            print(f"📁 File: {finding['file']}")
            print(f"📍 Line {finding['line']}: {finding['content']}")
            print(f"⚠️  Pattern: {finding['pattern']}")
            print("-" * 60)
        
        print("\n❌ SECURITY SCAN FAILED")
        print("Please review and remove potential backdoors!")
        sys.exit(1)
    else:
        print("\n✅ NO BACKDOORS FOUND")
        print("✅ SECURITY SCAN PASSED")
        sys.exit(0)

if __name__ == '__main__':
    main()
