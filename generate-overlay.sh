#!/bin/bash

# ============================================
# TrebleDroid Overlay Creator v2.0
# Interactive Script for Creating Android GSI Overlays
# Format: ro.product.device (Latest Standard)
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Global variables
WORK_DIR="$HOME/treble-overlay-work"
VENDOR_OVERLAY=""
PRODUCT_OVERLAY=""
BRAND_NAME=""
MODEL_NAME=""
DEVICE_CODENAME=""
PRIORITY="999"
DEVICE_FINGERPRINT=""
OVERLAY_REPO="https://github.com/TrebleDroid/vendor_hardware_overlay"

# ============================================
# Utility Functions
# ============================================

print_header() {
    clear
    echo "--------------------------------------------------------------"
    echo "           TrebleDroid Overlay Creator v2.0"
    echo "           Format: ro.product.device (Latest)"
    echo "--------------------------------------------------------------"
    echo ""
}

print_step() {
    echo ""
    echo "--------------------------------------------------------------"
    echo "STEP $1: $2"
    echo "--------------------------------------------------------------"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${MAGENTA}⚠ $1${NC}"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

pause() {
    echo ""
    read -p "Press Enter to continue..."
}

# ============================================
# Dependencies Setup
# ============================================

install_dependencies() {
    print_step "1" "Setup Dependencies & Tools"
    
    echo "Tools to be installed:"
    echo "  • git, xmlstarlet, aapt, apktool"
    echo "  • adb (android-tools-adb)"
    echo ""
    
    read -p "Continue with installation? (y/n): " confirm
    if [[ $confirm != [yY] ]]; then
        print_error "Setup cancelled"
        exit 1
    fi
    
    print_info "Updating package list..."
    sudo apt update -qq
    
    print_info "Installing packages..."
    sudo apt install -y -qq git xmlstarlet android-tools-adb
    
    if ! check_command apktool; then
        print_info "Installing apktool..."
        sudo apt install -y apktool || {
            print_info "Downloading apktool manually..."
            wget -q https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool -O /tmp/apktool
            wget -q https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.9.3.jar -O /tmp/apktool.jar
            sudo mv /tmp/apktool /usr/local/bin/apktool
            sudo mv /tmp/apktool.jar /usr/local/bin/apktool.jar
            sudo chmod +x /usr/local/bin/apktool
        }
    fi
    
    if ! check_command aapt; then
        print_info "Installing Android SDK Build Tools..."
        sudo apt install -y android-sdk-build-tools || {
            print_warning "Install aapt manually from Android SDK"
        }
    fi
    
    print_success "Dependencies installed!"
    pause
}

# ============================================
# Device Detection (CRITICAL UPDATE)
# ============================================

detect_device() {
    print_step "2" "Device Detection & Codename (NEW FORMAT)"
    
    echo "Select detection method:"
    echo ""
    echo "  1) Via ADB (PC connected to device)"
    echo "  2) Manual input (I know the codename)"
    echo "  3) From old fingerprint (convert)"
    echo ""
    
    read -p "Choice (1-3): " detect_choice
    
    case $detect_choice in
        1) detect_via_adb ;;
        2) manual_input_device ;;
        3) convert_from_fingerprint ;;
        *) 
            print_error "Invalid choice"
            detect_device
            ;;
    esac
}

detect_via_adb() {
    print_info "Checking ADB connection..."
    
    if ! check_command adb; then
        print_error "ADB not found!"
        exit 1
    fi
    
    if ! adb devices | grep -q "device$"; then
        print_error "No device detected!"
        echo ""
        print_info "Troubleshooting checklist:"
        echo "  ✓ USB Debugging enabled in Developer Options"
        echo "  ✓ Device connected via USB"
        echo "  ✓ Allow USB debugging on device screen"
        echo "  ✓ Try: adb kill-server && adb start-server"
        exit 1
    fi
    
    print_success "Device detected!"
    echo ""
    
    print_info "Getting ro.product.device..."
    DEVICE_CODENAME=$(adb shell getprop ro.product.device | tr -d '\r\n')
    
    if [ -z "$DEVICE_CODENAME" ]; then
        print_error "Failed to get device codename!"
        exit 1
    fi
    
    DEVICE_FINGERPRINT=$(adb shell getprop ro.vendor.build.fingerprint | tr -d '\r\n')
    BRAND_NAME=$(echo "$DEVICE_FINGERPRINT" | cut -d'/' -f1)
    MODEL_NAME=$(echo "$DEVICE_FINGERPRINT" | cut -d'/' -f2)
    
    echo ""
    echo "--------------------------------------------------------------"
    echo "  Device Detected:"
    echo ""
    echo "  Codename (NEW): ${DEVICE_CODENAME}"
    echo "  Brand:          ${BRAND_NAME}"
    echo "  Model:          ${MODEL_NAME}"
    echo ""
    echo "  Manifest Format: ro.product.device = ${DEVICE_CODENAME}"
    echo "--------------------------------------------------------------"
    echo ""
    
    pause
}

manual_input_device() {
    echo ""
    print_info "Enter your device information:"
    echo ""
    
    read -p "Device Codename (ro.product.device): " DEVICE_CODENAME
    read -p "Brand Name (e.g., samsung, xiaomi): " BRAND_NAME
    read -p "Model Name (e.g., a03, redmi_note_9): " MODEL_NAME
    
    if [ -z "$DEVICE_CODENAME" ] || [ -z "$BRAND_NAME" ] || [ -z "$MODEL_NAME" ]; then
        print_error "All fields are required!"
        manual_input_device
    fi
    
    echo ""
    print_success "Input accepted!"
    echo "  Codename: $DEVICE_CODENAME"
    pause
}

convert_from_fingerprint() {
    print_info "Converting from old format (fingerprint) to new format"
    echo ""
    read -p "Enter fingerprint (ro.vendor.build.fingerprint): " DEVICE_FINGERPRINT
    
    if [ -z "$DEVICE_FINGERPRINT" ]; then
        print_error "Fingerprint cannot be empty!"
        convert_from_fingerprint
    fi
    
    BRAND_NAME=$(echo "$DEVICE_FINGERPRINT" | cut -d'/' -f1)
    MODEL_NAME=$(echo "$DEVICE_FINGERPRINT" | cut -d'/' -f2)
    
    echo ""
    print_warning "For new format, we need the specific device codename"
    print_info "Usually codename differs from model name"
    echo "  Example: Model 'a03' -> Codename 'a03' or 'a03x'"
    echo ""
    read -p "Enter device codename: " DEVICE_CODENAME
    
    if [ -z "$DEVICE_CODENAME" ]; then
        DEVICE_CODENAME="$MODEL_NAME"
        print_info "Using model name as codename: $DEVICE_CODENAME"
    fi
    
    pause
}

# ============================================
# APK Extraction
# ============================================

extract_overlays() {
    print_step "3" "Extract Overlay APKs"
    
    TEMP_DIR="$WORK_DIR/apk-source-$(date +%s)"
    mkdir -p "$TEMP_DIR"
    
    echo "Select APK source:"
    echo ""
    echo "  1) From device via ADB (auto-pull)"
    echo "  2) From firmware file (already extracted)"
    echo "  3) Input path manually"
    echo ""
    
    read -p "Choice (1-3): " source_choice
    
    case $source_choice in
        1) pull_from_device ;;
        2) from_firmware ;;
        3) manual_apk_paths ;;
        *) 
            print_error "Invalid choice"
            extract_overlays
            ;;
    esac
}

pull_from_device() {
    print_info "Pulling overlay APKs from device..."
    
    VENDOR_FOUND=false
    PRODUCT_FOUND=false
    
    if adb shell test -f /system/vendor/overlay/framework-res__auto_generated_rro_vendor.apk 2>/dev/null; then
        adb pull /system/vendor/overlay/framework-res__auto_generated_rro_vendor.apk "$TEMP_DIR/vendor.apk" 2>/dev/null
        VENDOR_OVERLAY="$TEMP_DIR/vendor.apk"
        VENDOR_FOUND=true
    else
        VENDOR_APK=$(adb shell find /system/vendor/overlay -name "*framework-res*" -o -name "*rro*" 2>/dev/null | head -1 | tr -d '\r\n')
        if [ -n "$VENDOR_APK" ]; then
            adb pull "$VENDOR_APK" "$TEMP_DIR/vendor.apk"
            VENDOR_OVERLAY="$TEMP_DIR/vendor.apk"
            VENDOR_FOUND=true
        fi
    fi
    
    if adb shell test -f /system/product/overlay/framework-res__auto_generated_rro_product.apk 2>/dev/null; then
        adb pull /system/product/overlay/framework-res__auto_generated_rro_product.apk "$TEMP_DIR/product.apk" 2>/dev/null
        PRODUCT_OVERLAY="$TEMP_DIR/product.apk"
        PRODUCT_FOUND=true
    else
        PRODUCT_APK=$(adb shell find /system/product/overlay -name "*framework-res*" -o -name "*rro*" 2>/dev/null | head -1 | tr -d '\r\n')
        if [ -n "$PRODUCT_APK" ]; then
            adb pull "$PRODUCT_APK" "$TEMP_DIR/product.apk"
            PRODUCT_OVERLAY="$TEMP_DIR/product.apk"
            PRODUCT_FOUND=true
        fi
    fi
    
    echo ""
    if [ "$VENDOR_FOUND" = true ]; then
        print_success "Vendor overlay: $VENDOR_OVERLAY"
    else
        print_warning "Vendor overlay not found"
    fi
    
    if [ "$PRODUCT_FOUND" = true ]; then
        print_success "Product overlay: $PRODUCT_OVERLAY"
    else
        print_warning "Product overlay not found"
    fi
    
    if [ "$VENDOR_FOUND" = false ] && [ "$PRODUCT_FOUND" = false ]; then
        print_error "No overlays found!"
        echo ""
        print_info "Try manual path input:"
        manual_apk_paths
    else
        pause
    fi
}

from_firmware() {
    print_info "Please extract your firmware using 7-Zip ZS:"
    echo "  https://github.com/mcmilk/7-Zip-zstd/releases/latest"
    echo ""
    print_info "Look for files in:"
    echo "  • system/vendor/overlay/"
    echo "  • system/product/overlay/"
    echo ""
    manual_apk_paths
}

manual_apk_paths() {
    echo ""
    print_info "Enter path to APK files:"
    echo ""
    
    read -e -p "Path to vendor overlay APK (optional): " VENDOR_INPUT
    if [ -n "$VENDOR_INPUT" ] && [ -f "$VENDOR_INPUT" ]; then
        cp "$VENDOR_INPUT" "$TEMP_DIR/vendor.apk"
        VENDOR_OVERLAY="$TEMP_DIR/vendor.apk"
    fi
    
    while [ -z "$PRODUCT_OVERLAY" ] || [ ! -f "$PRODUCT_OVERLAY" ]; do
        read -e -p "Path to product overlay APK (required): " PRODUCT_INPUT
        if [ -f "$PRODUCT_INPUT" ]; then
            cp "$PRODUCT_INPUT" "$TEMP_DIR/product.apk"
            PRODUCT_OVERLAY="$TEMP_DIR/product.apk"
        else
            print_error "Invalid file: $PRODUCT_INPUT"
        fi
    done
    
    print_success "APK files ready!"
    pause
}

# ============================================
# Decompile & Compare
# ============================================

decompile_and_compare() {
    print_step "4" "Decompile & Compare Overlays"
    
    DECOMPILE_DIR="$WORK_DIR/decompiled"
    mkdir -p "$DECOMPILE_DIR"
    
    if [ -f "$PRODUCT_OVERLAY" ]; then
        print_info "Decompiling product overlay..."
        apktool d -f "$PRODUCT_OVERLAY" -o "$DECOMPILE_DIR/product" -q
        
        if [ -d "$DECOMPILE_DIR/product/res" ]; then
            print_success "Product overlay decompiled!"
        else
            print_error "Failed to decompile product overlay"
            exit 1
        fi
    fi
    
    if [ -f "$VENDOR_OVERLAY" ]; then
        print_info "Decompiling vendor overlay..."
        apktool d -f "$VENDOR_OVERLAY" -o "$DECOMPILE_DIR/vendor" -q
        print_success "Vendor overlay decompiled!"
    fi
    
    compare_resources
    
    pause
}

compare_resources() {
    print_info "Comparing resources..."
    
    OUTPUT_DIR="$WORK_DIR/overlay-files"
    mkdir -p "$OUTPUT_DIR/res/values"
    mkdir -p "$OUTPUT_DIR/res/xml"
    
    PRODUCT_RES="$DECOMPILE_DIR/product/res"
    
    declare -A VALUE_FILES=(
        ["arrays.xml"]="values"
        ["bools.xml"]="values"
        ["dimens.xml"]="values"
        ["integers.xml"]="values"
        ["strings.xml"]="values"
    )
    
    CONFIG_XML="$OUTPUT_DIR/res/values/config.xml"
    
    cat > "$CONFIG_XML" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
EOF
    
    for file in "${!VALUE_FILES[@]}"; do
        folder="${VALUE_FILES[$file]}"
        PRODUCT_FILE="$PRODUCT_RES/$folder/$file"
        VENDOR_FILE="$DECOMPILE_DIR/vendor/res/$folder/$file"
        
        if [ -f "$PRODUCT_FILE" ]; then
            print_info "Processing $file..."
            
            if [ -f "$VENDOR_FILE" ]; then
                extract_differences "$VENDOR_FILE" "$PRODUCT_FILE" >> "$CONFIG_XML"
            else
                extract_all_xml_content "$PRODUCT_FILE" >> "$CONFIG_XML"
            fi
        fi
    done
    
    echo "</resources>" >> "$CONFIG_XML"
    
    PRODUCT_POWER="$PRODUCT_RES/xml/power_profile.xml"
    VENDOR_POWER="$DECOMPILE_DIR/vendor/res/xml/power_profile.xml"
    
    if [ -f "$PRODUCT_POWER" ]; then
        if [ -f "$VENDOR_POWER" ]; then
            if ! diff -q "$VENDOR_POWER" "$PRODUCT_POWER" > /dev/null 2>&1; then
                print_info "Power profile differs, using from product..."
                cp "$PRODUCT_POWER" "$OUTPUT_DIR/res/xml/"
            else
                print_info "Power profile identical, not needed"
                rmdir "$OUTPUT_DIR/res/xml" 2>/dev/null || true
            fi
        else
            cp "$PRODUCT_POWER" "$OUTPUT_DIR/res/xml/"
        fi
    else
        rmdir "$OUTPUT_DIR/res/xml" 2>/dev/null || true
    fi
    
    if [ -s "$CONFIG_XML" ]; then
        print_success "config.xml created successfully!"
        echo ""
        echo "Preview (first 20 lines):"
        head -20 "$CONFIG_XML"
        echo ""
    else
        print_warning "config.xml is empty, no significant differences found"
    fi
}

extract_differences() {
    local vendor_file=$1
    local product_file=$2
    
    local tmp_dir="/tmp/xml_compare_$$"
    mkdir -p "$tmp_dir"
    
    xmlstarlet sel -t -m "//resources/*[@name]" -v "@name" -o "|" -v "name()" -n "$vendor_file" 2>/dev/null | sort > "$tmp_dir/vendor_res.txt"
    xmlstarlet sel -t -m "//resources/*[@name]" -v "@name" -o "|" -v "name()" -n "$product_file" 2>/dev/null | sort > "$tmp_dir/product_res.txt"
    
    while IFS='|' read -r name tag; do
        [ -z "$name" ] && continue
        
        vendor_val=$(xmlstarlet sel -t -m "/*/*[@name='$name']" -c "." "$vendor_file" 2>/dev/null | md5sum | cut -d' ' -f1)
        product_val=$(xmlstarlet sel -t -m "/*/*[@name='$name']" -c "." "$product_file" 2>/dev/null | md5sum | cut -d' ' -f1)
        
        if [ "$vendor_val" != "$product_val" ]; then
            xmlstarlet sel -t -m "/*/*[@name='$name']" -c "." "$product_file" 2>/dev/null | xmlstarlet fo --omit-decl 2>/dev/null
            echo ""
        fi
    done < "$tmp_dir/product_res.txt"
    
    rm -rf "$tmp_dir"
}

extract_all_xml_content() {
    local file=$1
    xmlstarlet sel -t -m "/resources/*" -c "." "$file" 2>/dev/null | xmlstarlet fo --omit-decl 2>/dev/null
}

# ============================================
# Generate Manifest (NEW FORMAT!)
# ============================================

generate_manifest() {
    print_step "5" "Generate AndroidManifest.xml (NEW FORMAT!)"
    
    echo "Old Format vs New Format:"
    echo ""
    echo "OLD FORMAT (Deprecated):"
    echo '  android:requiredSystemPropertyName="ro.vendor.build.fingerprint"'
    echo '  android:requiredSystemPropertyValue="+*BRAND/MODEL*"'
    echo ""
    echo "NEW FORMAT (Recommended):"
    echo '  android:requiredSystemPropertyName="ro.product.device"'
    echo '  android:requiredSystemPropertyValue="CODENAME"'
    echo ""
    print_info "New format is more stable and specific!"
    echo ""
    
    MANIFEST_FILE="$WORK_DIR/overlay-files/AndroidManifest.xml"
    
    cat > "$MANIFEST_FILE" << EOF
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
        package="me.phh.treble.overlay.${BRAND_NAME}.${DEVICE_CODENAME}"
        android:versionCode="1"
        android:versionName="1.0">
        <overlay android:targetPackage="android"
        	android:requiredSystemPropertyName="ro.product.device"
        	android:requiredSystemPropertyValue="${DEVICE_CODENAME}"
		android:priority="${PRIORITY}"
		android:isStatic="true" />
</manifest>
EOF
    
    print_success "AndroidManifest.xml created with NEW format!"
    echo ""
    echo "File contents:"
    cat "$MANIFEST_FILE"
    echo ""
    
    print_info "Format explanation:"
    echo "  • package: me.phh.treble.overlay.${BRAND_NAME}.${DEVICE_CODENAME}"
    echo "  • requiredSystemPropertyName: ro.product.device"
    echo "  • requiredSystemPropertyValue: ${DEVICE_CODENAME}"
    echo "  • priority: ${PRIORITY} (high priority to override GSI)"
    echo ""
    
    pause
}

generate_android_mk() {
    print_step "6" "Generate Android.mk"
    
    MK_FILE="$WORK_DIR/overlay-files/Android.mk"
    
    cat > "$MK_FILE" << EOF
LOCAL_PATH := \$(call my-dir)
include \$(CLEAR_VARS)
LOCAL_MODULE_TAGS := optional
LOCAL_PACKAGE_NAME := treble-overlay-${BRAND_NAME}-${DEVICE_CODENAME}
LOCAL_MODULE_PATH := \$(TARGET_OUT_PRODUCT)/overlay
LOCAL_IS_RUNTIME_RESOURCE_OVERLAY := true
LOCAL_PRIVATE_PLATFORM_APIS := true
include \$(BUILD_PACKAGE)
EOF
    
    print_success "Android.mk created!"
    echo ""
    cat "$MK_FILE"
    echo ""
    
    pause
}

# ============================================
# Testing & Validation
# ============================================

test_overlay() {
    print_step "7" "Testing & Validation"
    
    echo "How to test your overlay:"
    echo ""
    echo "1. Build APK using TrebleDroid repo:"
    echo "   git clone $OVERLAY_REPO"
    echo "   cd vendor_hardware_overlay"
    echo "   ./build/build.sh"
    echo ""
    echo "2. Install to device:"
    echo "   Via Magisk (Recommended):"
    echo "   • Create folder: /sdcard/overlay-test/"
    echo "   • Copy APK to /sdcard/overlay-test/system/product/overlay/"
    echo "   • Zip folder and install via Magisk Manager"
    echo ""
    echo "   Manual (Root required):"
    echo "   adb push treble-overlay-${BRAND_NAME}-${DEVICE_CODENAME}.apk /system/product/overlay/"
    echo "   adb reboot"
    echo ""
    echo "3. Verify overlay is active:"
    echo "   adb shell cmd overlay list --user current"
    echo ""
    echo "   Expected output:"
    echo "   [x] me.phh.treble.overlay.${BRAND_NAME}.${DEVICE_CODENAME}"
    echo ""
    
    TEST_SCRIPT="$WORK_DIR/test-overlay.sh"
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash

APK_FILE="\$1"

if [ -z "\$APK_FILE" ]; then
    echo "Usage: \$0 <path-to-apk>"
    exit 1
fi

echo "=== Testing Overlay ==="
echo "Checking if overlay is listed..."

adb shell cmd overlay list --user current | grep "${BRAND_NAME}.${DEVICE_CODENAME}"

if [ \$? -eq 0 ]; then
    echo "✓ Overlay detected!"
    echo ""
    echo "Overlay details:"
    adb shell cmd overlay dump me.phh.treble.overlay.${BRAND_NAME}.${DEVICE_CODENAME} 2>/dev/null || echo "Overlay not yet applied"
else
    echo "✗ Overlay not found"
    echo "Make sure APK is pushed to /system/product/overlay/"
fi
EOF
    
    chmod +x "$TEST_SCRIPT"
    print_success "Test script created: $TEST_SCRIPT"
    
    pause
}

# ============================================
# Repository Setup & Submit
# ============================================

setup_repo() {
    print_step "8" "Repository Setup & Submit"
    
    echo "Steps to submit to TrebleDroid:"
    echo ""
    echo "1. Fork repository:"
    echo "   $OVERLAY_REPO"
    echo ""
    echo "2. Clone your fork:"
    echo "   git clone https://github.com/YOUR_USERNAME/vendor_hardware_overlay.git"
    echo "   cd vendor_hardware_overlay"
    echo ""
    
    SETUP_SCRIPT="$WORK_DIR/setup-repo.sh"
    cat > "$SETUP_SCRIPT" << EOF
#!/bin/bash

REPO_PATH="\$1"

if [ -z "\$REPO_PATH" ]; then
    echo "Usage: \$0 /path/to/vendor_hardware_overlay"
    exit 1
fi

if [ ! -d "\$REPO_PATH/.git" ]; then
    echo "Error: \$REPO_PATH is not a git repository"
    exit 1
fi

BRAND="${BRAND_NAME}"
MODEL="${DEVICE_CODENAME}"
TARGET_DIR="\$REPO_PATH/overlay/\$BRAND/\$MODEL"

echo "Creating overlay structure..."
mkdir -p "\$TARGET_DIR/res/values"
mkdir -p "\$TARGET_DIR/res/xml" 2>/dev/null || true

echo "Copying files..."
cp "$WORK_DIR/overlay-files/AndroidManifest.xml" "\$TARGET_DIR/"
cp "$WORK_DIR/overlay-files/Android.mk" "\$TARGET_DIR/"

if [ -d "$WORK_DIR/overlay-files/res/values" ]; then
    cp "$WORK_DIR/overlay-files/res/values/"* "\$TARGET_DIR/res/values/" 2>/dev/null || true
fi

if [ -d "$WORK_DIR/overlay-files/res/xml" ]; then
    cp "$WORK_DIR/overlay-files/res/xml/"* "\$TARGET_DIR/res/xml/" 2>/dev/null || true
fi

echo ""
echo "✓ Files copied to: \$TARGET_DIR"
echo ""
echo "Next steps:"
echo "1. Edit \$REPO_PATH/overlay.mk"
echo "2. Add: treble-overlay-\$BRAND-\$MODEL \\"
echo "3. Run: ./tests/tests.sh"
echo "4. Commit and push to your fork"
echo "5. Create Pull Request on GitHub"
EOF
    
    chmod +x "$SETUP_SCRIPT"
    
    echo "3. Run setup script:"
    echo "   $SETUP_SCRIPT /path/to/vendor_hardware_overlay"
    echo ""
    echo "4. Update overlay.mk:"
    echo "   Add in alphabetical order:"
    echo "   treble-overlay-${BRAND_NAME}-${DEVICE_CODENAME} \\"
    echo ""
    echo "5. Test with:"
    echo "   ./tests/tests.sh"
    echo ""
    echo "6. Build with:"
    echo "   ./build/build.sh"
    echo ""
    echo "7. Commit & Push:"
    echo "   git add overlay/${BRAND_NAME}/${DEVICE_CODENAME}/"
    echo "   git add overlay.mk"
    echo "   git commit -m \"Add overlay for ${BRAND_NAME} ${DEVICE_CODENAME}\""
    echo "   git push origin master"
    echo ""
    echo "8. Create Pull Request on GitHub!"
    echo ""
    
    print_success "Setup script created: $SETUP_SCRIPT"
    
    pause
}

# ============================================
# Magisk Module Template
# ============================================

create_magisk_template() {
    print_step "9" "Magisk Module Template"
    
    MAGISK_DIR="$WORK_DIR/magisk-module-treble-overlay-${BRAND_NAME}-${DEVICE_CODENAME}"
    mkdir -p "$MAGISK_DIR/system/product/overlay"
    
    cat > "$MAGISK_DIR/module.prop" << EOF
id=treble-overlay-${BRAND_NAME}-${DEVICE_CODENAME}
name=Treble Overlay for ${BRAND_NAME} ${DEVICE_CODENAME}
version=1.0
versionCode=1
author=OverlayCreator
description=Hardware overlay for ${BRAND_NAME} ${DEVICE_CODENAME} to fix GSI compatibility issues. Format: ro.product.device=${DEVICE_CODENAME}
updateJson=
EOF
    
    cat > "$MAGISK_DIR/service.sh" << EOF
#!/system/bin/sh
log -t TrebleOverlay "Overlay ${BRAND_NAME}.${DEVICE_CODENAME} loaded"
EOF
    
    cat > "$MAGISK_DIR/customize.sh" << EOF
ui_print "Installing Treble Overlay for ${BRAND_NAME} ${DEVICE_CODENAME}"
ui_print "Target device: ${DEVICE_CODENAME}"
ui_print ""
ui_print "Place your APK in this module's system/product/overlay folder"
ui_print "The APK should be named: treble-overlay-${BRAND_NAME}-${DEVICE_CODENAME}.apk"
EOF
    
    chmod +x "$MAGISK_DIR/service.sh" 2>/dev/null || true
    
    print_success "Magisk module template created!"
    echo "Location: $MAGISK_DIR"
    echo ""
    print_info "How to use:"
    echo "1. Build APK using build/build.sh in TrebleDroid repo"
    echo "2. Copy APK to: $MAGISK_DIR/system/product/overlay/"
    echo "3. Rename APK to: treble-overlay-${BRAND_NAME}-${DEVICE_CODENAME}.apk"
    echo "4. Zip the $MAGISK_DIR folder"
    echo "5. Install via Magisk Manager"
    echo "6. Reboot and check: adb shell cmd overlay list --user current"
    echo ""
    
    pause
}

# ============================================
# Summary
# ============================================

show_summary() {
    print_step "10" "Summary & Next Steps"
    
    echo "--------------------------------------------------------------"
    echo "              OVERLAY CREATION COMPLETE!"
    echo "--------------------------------------------------------------"
    echo ""
    echo "Files created:"
    echo "  • Overlay files:     $WORK_DIR/overlay-files/"
    echo "  • Setup script:      $WORK_DIR/setup-repo.sh"
    echo "  • Test script:       $WORK_DIR/test-overlay.sh"
    echo "  • Magisk template:   $WORK_DIR/magisk-module-*/"
    echo ""
    echo "Device Info:"
    echo "  • Brand:    $BRAND_NAME"
    echo "  • Codename: $DEVICE_CODENAME"
    echo "  • Format:   ro.product.device = $DEVICE_CODENAME"
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Fork & Clone:"
    echo "   git clone https://github.com/YOUR_USERNAME/vendor_hardware_overlay.git"
    echo ""
    echo "2. Setup:"
    echo "   $WORK_DIR/setup-repo.sh /path/to/vendor_hardware_overlay"
    echo ""
    echo "3. Update overlay.mk:"
    echo "   add: treble-overlay-${BRAND_NAME}-${DEVICE_CODENAME} \\"
    echo ""
    echo "4. Test:"
    echo "   cd vendor_hardware_overlay && ./tests/tests.sh"
    echo ""
    echo "5. Build:"
    echo "   ./build/build.sh"
    echo ""
    echo "6. Test on Device:"
    echo "   • Copy APK to Magisk module"
    echo "   • Install & Reboot"
    echo "   • Check: adb shell cmd overlay list --user current"
    echo ""
    echo "7. Submit PR:"
    echo "   git add . && git commit -m \"Add overlay for ${DEVICE_CODENAME}\""
    echo "   git push && Create PR on GitHub"
    echo ""
    echo "Tips:"
    echo "   • Verify codename: adb shell getprop ro.product.device"
    echo "   • Priority 999 = high priority (override GSI defaults)"
    echo "   • New format (ro.product.device) is more stable!"
    echo ""
}

# ============================================
# Main Menu
# ============================================

main_menu() {
    print_header
    
    echo "Select mode:"
    echo ""
    echo "  1) Full Auto (All steps)"
    echo "  2) Quick Manifest Only"
    echo "  3) Generate from existing APK"
    echo "  4) Setup dependencies only"
    echo "  5) Exit"
    echo ""
    
    read -p "Choice (1-5): " choice
    
    case $choice in
        1) full_flow ;;
        2) quick_manifest ;;
        3) from_existing_apk ;;
        4) install_dependencies && main_menu ;;
        5) exit 0 ;;
        *) 
            print_error "Invalid choice"
            sleep 2
            main_menu
            ;;
    esac
}

full_flow() {
    install_dependencies
    detect_device
    extract_overlays
    decompile_and_compare
    generate_manifest
    generate_android_mk
    test_overlay
    setup_repo
    create_magisk_template
    show_summary
}

quick_manifest() {
    detect_device
    generate_manifest
    generate_android_mk
    echo ""
    print_success "Manifest ready at: $WORK_DIR/overlay-files/"
}

from_existing_apk() {
    detect_device
    
    TEMP_DIR="$WORK_DIR/apk-source-$(date +%s)"
    mkdir -p "$TEMP_DIR"
    
    echo ""
    read -e -p "Path to product overlay APK: " PRODUCT_OVERLAY
    if [ -f "$PRODUCT_OVERLAY" ]; then
        cp "$PRODUCT_OVERLAY" "$TEMP_DIR/product.apk"
        PRODUCT_OVERLAY="$TEMP_DIR/product.apk"
        
        read -e -p "Path to vendor overlay APK (optional): " VENDOR_OVERLAY
        if [ -f "$VENDOR_OVERLAY" ]; then
            cp "$VENDOR_OVERLAY" "$TEMP_DIR/vendor.apk"
            VENDOR_OVERLAY="$TEMP_DIR/vendor.apk"
        fi
        
        decompile_and_compare
        generate_manifest
        generate_android_mk
        create_magisk_template
        show_summary
    else
        print_error "Invalid file"
    fi
}

mkdir -p "$WORK_DIR"
main_menu
