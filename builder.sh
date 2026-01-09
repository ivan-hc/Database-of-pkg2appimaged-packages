#!/usr/bin/env bash

[ -z "$APP" ] && APP="SAMPLE"

# CREATE A TEMPORARY DIRECTORY
mkdir -p tmp && cd tmp || exit 1

# DOWNLOADING THE DEPENDENCIES
if test -f ./pkg2appimage; then
	echo " pkg2appimage already exists" 1> /dev/null
else
	echo " Downloading pkg2appimage..."
	wget -q https://github.com/ivan-hc/AppImaGen/releases/download/utilities/pkg2appimage -O pkg2appimage
fi
chmod a+x ./appimagetool ./pkg2appimage

# CREATING THE HEAD OF THE RECIPE
echo "app: $APP
binpatch: true

ingredients:

  dist: bullseye
  sources:
    - deb http://ftp.debian.org/debian/ bullseye main contrib non-free
    - deb http://security.debian.org/debian-security/ bullseye-security main contrib non-free
    - deb http://ftp.debian.org/debian/ bullseye-updates main contrib non-free
  packages:
    - $APP" > recipe.yml

# DOWNLOAD ALL THE NEEDED PACKAGES AND COMPILE THE APPDIR
./pkg2appimage ./recipe.yml

# COMPILE SCHEMAS
glib-compile-schemas "$APP"/"$APP".AppDir/usr/share/glib-2.0/schemas/ || echo "No ./usr/share/glib-2.0/schemas/"

# LIBUNIONPRELOAD
[ ! -f "$APP"/"$APP".AppDir/libunionpreload.so ] && wget https://github.com/project-portable/libunionpreload/releases/download/amd64/libunionpreload.so -O "$APP"/"$APP".AppDir/libunionpreload.so && chmod a+x libunionpreload.so

# APPRUN
rm -f "$APP"/"$APP".AppDir/AppRun
cat >> "$APP"/"$APP".AppDir/AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export UNION_PRELOAD="${HERE}"
export LD_PRELOAD="${HERE}"/libunionpreload.so
export PATH="${HERE}"/usr/bin/:"${HERE}"/usr/sbin/:"${HERE}"/usr/games/:"${HERE}"/bin/:"${HERE}"/sbin/:"${PATH}"
lib_dirs=$(find "$HERE"/usr/lib -type d | sed 's#usr/lib/#DEL\n#g' | grep -v DEL$)
for d in $lib_dirs; do
	export LD_LIBRARY_PATH="${HERE}"/usr/lib/"$d"/:"${LD_LIBRARY_PATH}"
done
export LD_LIBRARY_PATH="${HERE}"/usr/lib/:"${HERE}"/usr/lib/x86_64-linux-gnu/:"${HERE}"/lib/:"${HERE}"/lib64/:"${HERE}"/lib/x86_64-linux-gnu/:"${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH=/lib/:/lib64/:/lib/x86_64-linux-gnu/:/usr/lib/:"${LD_LIBRARY_PATH}" # Uncomment to use system libraries
export XDG_DATA_DIRS="${HERE}"/usr/share/:"${XDG_DATA_DIRS}"
export GSETTINGS_SCHEMA_DIR="${HERE}"/usr/share/glib-2.0/schemas/:"${GSETTINGS_SCHEMA_DIR}"

exec "${HERE}"/usr/bin/SAMPLE "$@"
EOF
sed -i "s/SAMPLE/$APP/g" "$APP"/"$APP".AppDir/AppRun

# MADE THE APPRUN EXECUTABLE
chmod a+x "$APP"/"$APP".AppDir/AppRun
# END OF THE PART RELATED TO THE APPRUN, NOW WE WELL SEE IF EVERYTHING WORKS ----------------------------------------------------------------------

# IMPORT THE LAUNCHER AND THE ICON TO THE APPDIR IF THEY NOT EXIST
if test -f "$APP"/"$APP".AppDir/*.desktop; then
	echo "The desktop file exists"
else
	echo "Trying to get the .desktop file"
	cp "$APP"/"$APP".AppDir/usr/share/applications/*$(ls . | grep -i "$APP" | cut -c -4)*desktop "$APP"/"$APP".AppDir/ 2>/dev/null
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
ICONNAME=$(cat "$APP"/"$APP".AppDir/*desktop | grep "Icon=" | head -1 | cut -c 6-)
hicolor_dirs="22x22 24x24 32x32 48x4 64x64 128x128 192x192 256x256 512x512 scalable"
for i in $hicolor_dirs; do
	cp -r "$APP"/"$APP".AppDir/usr/share/icons/hicolor/"$i"/apps/*"$ICONNAME"* "$APP"/"$APP".AppDir/ 2>/dev/null || cp -r "$APP"/"$APP".AppDir/usr/share/icons/hicolor/"$i"/mimetypes/*"$ICONNAME"* "$APP"/"$APP".AppDir/ 2>/dev/null
done
cp "$APP"/"$APP".AppDir/usr/share/applications/*"$ICONNAME"* "$APP"/"$APP".AppDir/ 2>/dev/null

# UNCOMMENT THE FOLLOWING LINE TO REMOVE FILES IN "METAINFO" IN CASE OF ERRORS WITH "APPSTREAM"
rm -Rf "$APP"/"$APP".AppDir/usr/share/metainfo/* "$APP"/"$APP".AppDir/usr/share/doc "$APP"/"$APP".AppDir/usr/share/perl "$APP"/"$APP".AppDir/usr/lib/*/perl

# EXPORT THE APP TO AN APPIMAGE
APPNAME=$(cat "$APP"/"$APP".AppDir/*.desktop | grep '^Name=' | head -1 | cut -c 6- | sed 's/ /-/g')
REPO="GNOME3-appimages"
TAG="$APP"
UPINFO="gh-releases-zsync|$GITHUB_REPOSITORY_OWNER|$REPO|$TAG|*x86_64.AppImage.zsync"

_appimagetool() {
	if ! command -v appimagetool 1>/dev/null; then
		if [ ! -f ./appimagetool ]; then
			echo " Downloading appimagetool..." && curl -#Lo appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-"$ARCH".AppImage && chmod a+x ./appimagetool || exit 1
		fi
		./appimagetool "$@"
	else
		appimagetool "$@"
	fi
}

ARCH=x86_64 _appimagetool -u "$UPINFO" "$APP"/"$APP".AppDir "$APPNAME"_"$PKG_VERSION"-x86_64.AppImage

cd ..
mv ./tmp/*.AppImage* .
chmod a+x *.AppImage
