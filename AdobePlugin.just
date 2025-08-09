set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

TargetDir := env_var("CARGO_TARGET_DIR")
# export AESDK_ROOT := if env("AESDK_ROOT", "") == "" { justfile_directory() / "../../sdk/AfterEffectsSDK" } else { env_var("AESDK_ROOT") }
# export PRSDK_ROOT := if env("PRSDK_ROOT", "") == "" { justfile_directory() / "../../sdk/Premiere Pro 22.0 C++ SDK" } else { env_var("PRSDK_ROOT") }

[windows]
build:
    cargo build
    if (-not $env:NO_INSTALL) { \
        cp -Rf '{{TargetDir}}\debug\{{BinaryName}}.dll' 'C:\Program Files\Adobe\Common\Plug-ins\7.0\MediaCore\{{PluginName}}.aex' \
    }

[windows]
fastdebug:
    cargo build --profile fastdebug
    cp -Rf '{{TargetDir}}\fastdebug\{{BinaryName}}.dll' 'C:\Program Files\Adobe\Common\Plug-ins\7.0\MediaCore\Haligonian\{{PluginName}}.aex' \

[windows]
release:
    cargo build --release
    Copy-Item -Force '{{TargetDir}}\release\{{BinaryName}}.dll' '{{TargetDir}}\release\{{PluginName}}.aex'
    if (-not $env:NO_INSTALL) { \
        cp -Rf '{{TargetDir}}\debug\{{BinaryName}}.dll' 'C:\Program Files\Adobe\Common\Plug-ins\7.0\MediaCore\{{PluginName}}.aex' \
    }

[macos]
build:
    cargo build
    just -f {{justfile()}} create_bundle debug {{TargetDir}}

[macos]
fastdebug:
    cargo build --profile fastdebug
    just -f {{justfile()}} create_bundle fastdebug {{TargetDir}}

[macos]
release:
    cargo build --release
    just -f {{justfile()}} create_bundle release {{TargetDir}}

[macos]
releaseandnotarize:
    cargo build --release
    NOTARIZE=1 just -f {{justfile()}} create_bundle release {{TargetDir}}

[macos]
create_bundle profile TargetDir:
    #!/bin/bash
    set -e
    echo "Creating plugin bundle"
    rm -Rf {{TargetDir}}/{{profile}}/{{PluginName}}.plugin
    mkdir -p {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/Resources
    mkdir -p {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/MacOS

    if [ "{{profile}}" == "release" ]; then
        # Build universal binary
        rustup target add aarch64-apple-darwin
        rustup target add x86_64-apple-darwin

        cargo build --release --target x86_64-apple-darwin
        cargo build --release --target aarch64-apple-darwin

        cp {{TargetDir}}/x86_64-apple-darwin/release/{{BinaryName}}.rsrc {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/Resources/{{PluginName}}.rsrc
        cp {{TargetDir}}/x86_64-apple-darwin/release/{{BinaryName}}_PkgInfo {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/PkgInfo
        cp {{TargetDir}}/x86_64-apple-darwin/release/{{BinaryName}}_Info.plist {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/Info.plist
        lipo {{TargetDir}}/{x86_64,aarch64}-apple-darwin/release/lib{{BinaryName}}.dylib -create -output {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/MacOS/{{PluginName}}.dylib
        mv {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/MacOS/{{PluginName}}.dylib {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/MacOS/{{PluginName}}
    else
        cp {{TargetDir}}/{{profile}}/{{BinaryName}}.rsrc {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/Resources/{{PluginName}}.rsrc
        cp {{TargetDir}}/{{profile}}/{{BinaryName}}_PkgInfo {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/PkgInfo
        cp {{TargetDir}}/{{profile}}/{{BinaryName}}_Info.plist {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/Info.plist
        cp {{TargetDir}}/{{profile}}/lib{{BinaryName}}.dylib {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/MacOS/{{PluginName}}
    fi
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier "{{BundleIdentifier}}"' {{TargetDir}}/{{profile}}/{{PluginName}}.plugin/Contents/Info.plist

    # codesign with the first development cert we can find using its hash
    if [ -z "$NO_SIGN" ]; then
        codesign --force --deep --options runtime -strict  --sign $( security find-identity -v -p codesigning | grep -m 1 "Developer ID Application" | awk -F ' ' '{print $2}' ) {{TargetDir}}/{{profile}}/{{PluginName}}.plugin
    fi

    # notarize plugin
    if [ -n "$NOTARIZE" ]; then
        # We sign without --timestamp, then re-sign with --timestamp before notarizing, because signing with --timestamp requires internet and takes time
        echo "Notarizing plugin..."
        codesign --force --deep --options runtime --timestamp -strict  --sign $( security find-identity -v -p codesigning | grep -m 1 "Developer ID Application" | awk -F ' ' '{print $2}' ) {{TargetDir}}/{{profile}}/{{PluginName}}.plugin
        ../../notarize_plugin.sh {{TargetDir}}/{{profile}}/{{PluginName}}.plugin
    fi

    # Install
    if [ -z "$NO_INSTALL" ]; then
        sudo cp -rf "{{TargetDir}}/{{profile}}/{{PluginName}}.plugin" "/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore/Haligonian"
    fi
