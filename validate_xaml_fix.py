#!/usr/bin/env python3
"""
XAML XML Validation Script - Validates the fix for MC3000 errors
This script validates that all XAML files pass XML parsing after fixing unescaped ampersands.
"""

import xml.etree.ElementTree as ET
import os
import sys
from pathlib import Path

def validate_xml_file(file_path):
    """Validate a single XML/XAML file"""
    try:
        ET.parse(file_path)
        return True, None
    except ET.ParseError as e:
        return False, f"Line {e.lineno}, Position {e.offset}: {e.msg}"
    except Exception as e:
        return False, str(e)

def find_xaml_files(directory):
    """Find all XAML files in directory"""
    xaml_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.xaml'):
                xaml_files.append(os.path.join(root, file))
    return sorted(xaml_files)

def main():
    print("🔍 XAML XML Validation - MC3000 Error Fix Verification")
    print("=" * 60)
    
    # Find project directory
    project_dir = Path(__file__).parent / "KOALAOptimizer.Testing"
    if not project_dir.exists():
        print(f"❌ Project directory not found: {project_dir}")
        return False
        
    # Find all XAML files
    xaml_files = find_xaml_files(project_dir)
    if not xaml_files:
        print(f"❌ No XAML files found in {project_dir}")
        return False
    
    print(f"📁 Found {len(xaml_files)} XAML files to validate:\n")
    
    all_valid = True
    main_window_checked = False
    
    for xaml_file in xaml_files:
        rel_path = os.path.relpath(xaml_file, project_dir)
        is_valid, error = validate_xml_file(xaml_file)
        
        if is_valid:
            print(f"✅ {rel_path}")
            # Special check for MainWindow.xaml - the file we fixed
            if "MainWindow.xaml" in xaml_file:
                main_window_checked = True
                print(f"   🎯 MainWindow.xaml - PRIMARY FIX VERIFIED")
        else:
            print(f"❌ {rel_path}")
            print(f"   Error: {error}")
            all_valid = False
    
    print("\n" + "=" * 60)
    
    if all_valid:
        print("🎉 SUCCESS: All XAML files pass XML validation!")
        if main_window_checked:
            print("✅ MainWindow.xaml MC3000 error has been RESOLVED")
        print("\n📋 Summary of fixes applied:")
        print("   • Line 170: 'Smart Gaming Detection & Auto-Optimization' → '&amp;' escaped")
        print("   • Line 217: 'Power Management & Performance' → '&amp;' escaped") 
        print("   • Line 247: 'Enhanced GPU & DirectX' → '&amp;' escaped")
        print("   • Line 264: 'MMCSS & System Services' → '&amp;' escaped")
        print("\n🚀 The MSBuild compilation should now succeed without MC3000 XML parsing errors!")
        return True
    else:
        print("❌ FAILURE: Some XAML files still have XML parsing errors")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)