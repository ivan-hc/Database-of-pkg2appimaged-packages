#!/usr/bin/env bash

APP=baobab

# CREATE A TEMPORARY DIRECTORY
mkdir -p tmp
cd tmp

# DOWNLOADING THE DEPENDENCIES
if test -f ./appimagetool; then
	echo " appimagetool already exists" 1> /dev/null
else
	echo " Downloading appimagetool..."
	wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
fi
export URUNTIME_PRELOAD=1

if test -f ./pkg2appimage; then
	echo " pkg2appimage already exists" 1> /dev/null
else
	echo " Downloading pkg2appimage..."
	wget -q https://github.com/ivan-hc/AppImaGen/releases/download/utilities/pkg2appimage -O pkg2appimage
fi
chmod a+x ./appimagetool ./pkg2appimage
rm -f ./recipe.yml

# CREATING THE HEAD OF THE RECIPE
echo "app: baobab
binpatch: true

ingredients:

  dist: bullseye
  sources:
    - deb http://ftp.debian.org/debian/ bullseye main contrib non-free
    - deb http://security.debian.org/debian-security/ bullseye-security main contrib non-free
    - deb http://ftp.debian.org/debian/ bullseye-updates main contrib non-free
  packages:
    - baobab" >> recipe.yml

# DOWNLOAD ALL THE NEEDED PACKAGES AND COMPILE THE APPDIR
./pkg2appimage ./recipe.yml

# COMPILE SCHEMAS
glib-compile-schemas ./"$APP"/"$APP".AppDir/usr/share/glib-2.0/schemas/ || echo "No ./usr/share/glib-2.0/schemas/"

# CUSTOMIZE THE APPRUN
rm -R -f ./"$APP"/"$APP".AppDir/AppRun
cat >> ./"$APP"/"$APP".AppDir/AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"

export PATH="${HERE}"/usr/bin/:"${HERE}"/usr/sbin/:"${HERE}"/usr/games/:"${HERE}"/bin/:"${HERE}"/sbin/:"${PATH}"

lib_dirs=$(find "$HERE"/usr/lib -type d | sed 's#usr/lib/#DEL\n#g' | grep -v DEL$)
for d in $lib_dirs; do
	export LD_LIBRARY_PATH="${HERE}"/usr/lib/"$d"/:"${LD_LIBRARY_PATH}"
done

export LD_LIBRARY_PATH="${HERE}"/usr/lib/:"${HERE}"/usr/lib/x86_64-linux-gnu/:"${HERE}"/lib/:"${HERE}"/lib64/:"${HERE}"/lib/x86_64-linux-gnu/:"${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH=/lib/:/lib64/:/lib/x86_64-linux-gnu/:/usr/lib/:"${LD_LIBRARY_PATH}" # Uncomment to use system libraries

export XDG_DATA_DIRS="${HERE}"/usr/share/:"${XDG_DATA_DIRS}"

export GSETTINGS_SCHEMA_DIR="${HERE}"/usr/share/glib-2.0/schemas/:"${GSETTINGS_SCHEMA_DIR}"

exec "${HERE}"/usr/bin/baobab "$@"
EOF

# MADE THE APPRUN EXECUTABLE
chmod a+x ./"$APP"/"$APP".AppDir/AppRun
# END OF THE PART RELATED TO THE APPRUN, NOW WE WELL SEE IF EVERYTHING WORKS ----------------------------------------------------------------------

# IMPORT THE LAUNCHER AND THE ICON TO THE APPDIR IF THEY NOT EXIST
if test -f ./"$APP"/"$APP".AppDir/*.desktop; then
	echo "The desktop file exists"
else
	echo "Trying to get the .desktop file"
	cp ./"$APP"/"$APP".AppDir/usr/share/applications/*$(ls . | grep -i "$APP" | cut -c -4)*desktop ./"$APP"/"$APP".AppDir/ 2>/dev/null
fi

# VERSION
MAIN_DEB=$(find . -type f -name "$APP\_*.deb" | head -1 | sed 's:.*/::')
if test -f "$APP"/"$MAIN_DEB"; then
	ar x "$APP"/"$MAIN_DEB" && tar xf ./control.tar.* && rm -f ./control.tar.* ./data.tar.* || exit 1
	PKG_VERSION=$(grep Version 0<control | cut -c 10-)
else
	PKG_VERSION="test"
fi

# ICON
ICONNAME=$(cat ./"$APP"/"$APP".AppDir/*desktop | grep "Icon=" | head -1 | cut -c 6-)
cp ./"$APP"/"$APP".AppDir/usr/share/icons/hicolor/22x22/apps/*"$ICONNAME"* ./"$APP"/"$APP".AppDir/ 2>/dev/null
cp ./"$APP"/"$APP".AppDir/usr/share/icons/hicolor/24x24/apps/*"$ICONNAME"* ./"$APP"/"$APP".AppDir/ 2>/dev/null
cp ./"$APP"/"$APP".AppDir/usr/share/icons/hicolor/32x32/apps/*"$ICONNAME"* ./"$APP"/"$APP".AppDir/ 2>/dev/null
cp ./"$APP"/"$APP".AppDir/usr/share/icons/hicolor/48x48/apps/*"$ICONNAME"* ./"$APP"/"$APP".AppDir/ 2>/dev/null
cp ./"$APP"/"$APP".AppDir/usr/share/icons/hicolor/64x64/apps/*"$ICONNAME"* ./"$APP"/"$APP".AppDir/ 2>/dev/null
cp ./"$APP"/"$APP".AppDir/usr/share/icons/hicolor/128x128/apps/*"$ICONNAME"* ./"$APP"/"$APP".AppDir/ 2>/dev/null
cp ./"$APP"/"$APP".AppDir/usr/share/icons/hicolor/256x256/apps/*"$ICONNAME"* ./"$APP"/"$APP".AppDir/ 2>/dev/null
cp ./"$APP"/"$APP".AppDir/usr/share/icons/hicolor/512x512/apps/*"$ICONNAME"* ./"$APP"/"$APP".AppDir/ 2>/dev/null
cp ./"$APP"/"$APP".AppDir/usr/share/icons/hicolor/scalable/apps/*"$ICONNAME"* ./"$APP"/"$APP".AppDir/ 2>/dev/null
cp ./"$APP"/"$APP".AppDir/usr/share/applications/*"$ICONNAME"* ./"$APP"/"$APP".AppDir/ 2>/dev/null

# UNCOMMENT THE FOLLOWING LINE TO REMOVE FILES IN "METAINFO" IN CASE OF ERRORS WITH "APPSTREAM"
rm -R -f ./"$APP"/"$APP".AppDir/usr/share/metainfo/*

# EXPORT THE APP TO AN APPIMAGE
ARCH=x86_64 VERSION="$PKG_VERSION" ./appimagetool --comp zstd --mksquashfs-opt -Xcompression-level --mksquashfs-opt 20 ./"$APP"/"$APP".AppDir
cd ..
mv ./tmp/*.AppImage .
chmod a+x *.AppImage
