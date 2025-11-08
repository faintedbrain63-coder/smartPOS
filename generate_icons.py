#!/usr/bin/env python3
"""
SmartPOS Icon Generator
Generates all required icon sizes for Android and iOS from SVG source
"""

import os
import subprocess
import sys

def run_command(cmd):
    """Run a shell command and return success status"""
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr

def check_dependencies():
    """Check if required tools are available"""
    success, _ = run_command("which rsvg-convert")
    if not success:
        print("Error: rsvg-convert not found. Installing librsvg...")
        success, _ = run_command("brew install librsvg")
        if not success:
            print("Failed to install librsvg. Please install it manually:")
            print("brew install librsvg")
            return False
    return True

def generate_png_from_svg(svg_path, output_path, size):
    """Generate PNG from SVG at specified size"""
    cmd = f"rsvg-convert -w {size} -h {size} '{svg_path}' -o '{output_path}'"
    success, error = run_command(cmd)
    if success:
        print(f"✓ Generated {output_path} ({size}x{size})")
        return True
    else:
        print(f"✗ Failed to generate {output_path}: {error}")
        return False

def main():
    # Check dependencies
    if not check_dependencies():
        sys.exit(1)
    
    # Paths
    svg_path = "assets/smartpos_icon.svg"
    
    if not os.path.exists(svg_path):
        print(f"Error: SVG file not found at {svg_path}")
        sys.exit(1)
    
    # Android icon sizes and paths
    android_icons = [
        ("android/app/src/main/res/mipmap-mdpi/ic_launcher.png", 48),
        ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png", 72),
        ("android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", 96),
        ("android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", 144),
        ("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192),
    ]
    
    # iOS icon sizes and paths
    ios_icons = [
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", 20),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", 40),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", 60),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", 29),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", 58),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", 87),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", 40),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", 80),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", 120),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", 120),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", 180),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", 76),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", 152),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", 167),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", 1024),
    ]
    
    # Web icons
    web_icons = [
        ("web/icons/Icon-192.png", 192),
        ("web/icons/Icon-512.png", 512),
        ("web/icons/Icon-maskable-192.png", 192),
        ("web/icons/Icon-maskable-512.png", 512),
        ("web/favicon.png", 32),
    ]
    
    all_icons = android_icons + ios_icons + web_icons
    
    print("Generating SmartPOS app icons...")
    print(f"Source: {svg_path}")
    print(f"Total icons to generate: {len(all_icons)}")
    print()
    
    success_count = 0
    
    for icon_path, size in all_icons:
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(icon_path), exist_ok=True)
        
        if generate_png_from_svg(svg_path, icon_path, size):
            success_count += 1
    
    print()
    print(f"Icon generation complete: {success_count}/{len(all_icons)} successful")
    
    if success_count == len(all_icons):
        print("✓ All icons generated successfully!")
        return True
    else:
        print("✗ Some icons failed to generate")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)