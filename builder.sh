#!/usr/bin/env bash

[ -z "$APP" ] && APP="SAMPLE"

# CREATE A TEMPORARY DIRECTORY
mkdir -p tmp && cd tmp || exit 1

# DOWNLOAD DEPENDENCIES
if test -f ./pkg2appimage; then
	echo " pkg2appimage already exists" 1> /dev/null
else
	echo " Downloading pkg2appimage..."
	wget -q https://github.com/ivan-hc/AppImaGen/releases/download/utilities/pkg2appimage -O pkg2appimage
fi
chmod a+x ./appimagetool ./pkg2appimage

# RECIPE
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

# COMPILE THE APPDIR
./pkg2appimage ./recipe.yml

# COMPILE SCHEMAS
glib-compile-schemas "$APP"/"$APP".AppDir/usr/share/glib-2.0/schemas/ || echo "No ./usr/share/glib-2.0/schemas/"

# APPRUN
rm -f "$APP"/"$APP".AppDir/AppRun

_add_apprun_header() {
	cat <<-'HEREDOC' >> "$APP"/"$APP".AppDir/AppRun
	#!/bin/sh
	HERE="$(dirname "$(readlink -f "${0}")")"
	export APPDIR="$HERE"  # <--- ADD THIS LINE
	HEREDOC
}

_add_apprun_footer() {
	cat <<-'HEREDOC' >> "$APP"/"$APP".AppDir/AppRun
	export PATH="${HERE}"/usr/bin/:"${HERE}"/usr/sbin/:"${HERE}"/usr/games/:"${HERE}"/bin/:"${HERE}"/sbin/:"${PATH}"

	lib_dirs_in=$(find "$HERE" -type f -name 'lib*.so*' -printf '%h\n' | sed "s|^$HERE||" | sort -u)
	lib_dirs_out=$(ldd "${HERE}"/usr/bin/SAMPLE | awk '/=>/ { print $3 }' | xargs -r dirname | sort -u | grep -v "^/tmp")
	for d in $lib_dirs_in; do export LD_LIBRARY_PATH="${HERE}""$d":"${LD_LIBRARY_PATH}"; done
	for d in $lib_dirs_out; do export LD_LIBRARY_PATH="$d":"${LD_LIBRARY_PATH}"; done

	export XDG_DATA_DIRS="${HERE}"/usr/share/:"${XDG_DATA_DIRS}"

	export GSETTINGS_SCHEMA_DIR="${HERE}"/usr/share/glib-2.0/schemas/:"${GSETTINGS_SCHEMA_DIR}"

	export GI_TYPELIB_PATH="${HERE}/usr/lib/girepository-1.0:${HERE}/usr/lib/x86_64-linux-gnu/girepository-1.0:${GI_TYPELIB_PATH}"

	if test -d "${HERE}"/usr/lib/python*; then
	  PYTHONVERSION=$(find "${HERE}"/usr/lib -type d -name "python*" | head -1 | sed 's:.*/::')
	  export PYTHONPATH="${HERE}"/usr/lib/"$PYTHONVERSION"/site-packages/:"${HERE}"/usr/lib/"$PYTHONVERSION"/lib-dynload/:"${PYTHONPATH}"
	  export PYTHONHOME="${HERE}"/usr/
	fi

	exec "${HERE}"/usr/bin/SAMPLE "$@"
	HEREDOC
	sed -i "s/SAMPLE/$APP/g" "$APP"/"$APP".AppDir/AppRun
	chmod a+x "$APP"/"$APP".AppDir/AppRun
}

_add_libunionpreload() {
	# Use libunionpreload.so to allow the AppImage to run any .gresource files (and locale files)
	if [ ! -f "$APP"/"$APP".AppDir/libunionpreload.so ]; then
		wget -q https://github.com/project-portable/libunionpreload/releases/download/amd64/libunionpreload.so -O "$APP"/"$APP".AppDir/libunionpreload.so && chmod a+x libunionpreload.so
	fi
	[ ! -f "$APP"/"$APP".AppDir/libunionpreload.so ] && exit 1

	cat <<-'HEREDOC' >> "$APP"/"$APP".AppDir/AppRun
	export UNION_PRELOAD="${HERE}"
	export LD_PRELOAD="${HERE}"/libunionpreload.so
	HEREDOC
}

_add_liblocale_intercept() {
	# Create and use liblocale_intercept.so to allow your app talking your language
	if [ ! -f ./liblocale_intercept.so ]; then
		cat <<-'HEREDOC' >> locale_intercept.c
		#define _GNU_SOURCE
		#include <dlfcn.h>
		#include <stdlib.h>
		#include <string.h>
		#include <stdio.h>

		// This overrides the bindtextdomain function for ANY app
		char* bindtextdomain(const char* domainname, const char* dirname) {
		    // Load the real system function
		    static char* (*real_bindtextdomain)(const char*, const char*) = NULL;
		    if (!real_bindtextdomain) {
		        real_bindtextdomain = dlsym(RTLD_NEXT, "bindtextdomain");
		    }

		    // If APPDIR is set (which your AppRun will do), redirect ALL locales there
		    char* appdir = getenv("APPDIR");
		    if (appdir) {
		        // Construct the path to the AppImage's locale folder
		        char fixed_path[512];
		        snprintf(fixed_path, sizeof(fixed_path), "%s/usr/share/locale", appdir);

		        // Force the app to use this path, ignoring the hardcoded path
		        return real_bindtextdomain(domainname, fixed_path);
		    }

		    // Fallback if not running as AppImage
		    return real_bindtextdomain(domainname, dirname);
		}
		HEREDOC
		gcc -shared -fPIC -o liblocale_intercept.so locale_intercept.c -ldl
	fi

	[ ! -f ./liblocale_intercept.so ] && exit 1
	cp -r liblocale_intercept.so "$APP"/"$APP".AppDir/usr/lib/

	cat <<-'HEREDOC' >> "$APP"/"$APP".AppDir/AppRun
	export LD_PRELOAD="${HERE}"/usr/lib/liblocale_intercept.so:"${LD_PRELOAD}"
	HEREDOC
}

GRESOURCE_FILE=$(find "$APP"/"$APP".AppDir/usr/share -type f -name *.gresource)
if [ -n "$GRESOURCE_FILE" ]; then
	_add_apprun_header
	_add_libunionpreload
	_add_apprun_footer
else
	_add_apprun_header
	_add_liblocale_intercept
	_add_apprun_footer
fi

# LAUNCHER
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

# REMOVE METAINFO TO PREVENT "APPSTREAM" ERRORS
rm -Rf "$APP"/"$APP".AppDir/usr/share/metainfo/*

# REMOVE BLOATWARE
rm -Rf "$APP"/"$APP".AppDir/usr/share/doc "$APP"/"$APP".AppDir/usr/share/perl "$APP"/"$APP".AppDir/usr/lib/*/perl

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
