#!/usr/bin/env bash
echo "Usage: ${0} [-c] [path to Python frameworks]"
printf "\nThis script fixes Python tcl/tk so that an application built with pyinstaller can be submitted to the App Store."
echo "This is necessary because tcl8.6 includes a reference to NSWindowDidOrderOnScreenNotification which is a deprecated API. It does not appear to be used by Tk so can be commented out."
echo "See https://core.tcl-lang.org/tk/tktview/a9969f7ffd966229c4e6 for more details."
echo "-c cleans the working folder and deletes past build artifacts and downoaded files"
printf "[path to Python frameworks] is the path to your working copy of Python's Frameworks directory; default is /Library/Frameworks/Python.framework/Versions/Current/Frameworks\n\n"
framework_path=$(realpath '/Library/Frameworks/Python.framework/Versions/Current/Frameworks')
output_folder=$(mktemp -d -t fix-tk.xxxx)
echo "tcl/tk will be temporarily installed in ${output_folder}. This can be safely deleted after a successful run."
[ "${1}" == "-c" ] && shift && rm -rf tcl8.6.17 tcl8.6.17-src.tar.gz tk8.6.17 tk8.6.17-src.tar.gz build && echo 'Prior build artifacts removed.'
[ -n "${1}" ] && framework_path="${1}"

echo "Downloading tcl and tk."
[ -e tcl8.6.17-src.tar.gz ] || curl -L -sS -o tcl8.6.17-src.tar.gz 'https://downloads.sourceforge.net/project/tcl/Tcl/8.6.17/tcl8.6.17-src.tar.gz'
[ -e tk8.6.17-src.tar.gz ] || curl -L -sS -o tk8.6.17-src.tar.gz 'https://downloads.sourceforge.net/project/tcl/Tcl/8.6.17/tk8.6.17-src.tar.gz'
tar xfz tcl8.6.17-src.tar.gz || {
	echo 'Extracting of tcl source code failed. Exiting.'
	exit 1
}
tar xfz tk8.6.17-src.tar.gz || {
	echo 'Extracting of tk source code failed. Exiting.'
	exit 1
}
[ -e tcl8.6.17/macosx/GNUmakefile ] && [ -e tk8.6.17/macosx/GNUmakefile ] || {
	echo 'GNUmakefile not found. Something went wrong. Exiting.'
	exit 1
}
echo "Patching source code."
patch -t <<'EOF'
diff -r -u tk8.6.17/library/tk.tcl tk8.6.18a/library/tk.tcl
--- tk8.6.17/library/tk.tcl	2025-07-31 13:34:03
+++ tk8.6.18a/library/tk.tcl	2026-05-03 21:48:23
@@ -11,7 +11,7 @@
 # this file, and for a DISCLAIMER OF ALL WARRANTIES.
 
 # Verify that we have Tk binary and script components from the same release
-package require -exact Tk  8.6.17
+package require -exact Tk  8.6.18a
 
 # Create a ::tk namespace
 namespace eval ::tk {
diff -r -u tcl8.6.17/library/init.tcl tcl8.6.18a/library/init.tcl
--- tcl8.6.17/library/init.tcl	2025-07-31 13:29:02
+++ tcl8.6.18a/library/init.tcl	2026-05-03 21:47:55
@@ -18,7 +18,7 @@
 if {[info commands package] == ""} {
 }
-package require -exact Tcl 8.6.17
+package require -exact Tcl 8.6.18a
 
 # Compute the auto path to use in this interpreter.
 # The values on the path come from several locations:
diff -r -u tcl8.6.17/generic/tcl.h tcl8.6.18a/generic/tcl.h
--- tcl8.6.17/generic/tcl.h	2025-07-31 13:29:02
+++ tcl8.6.18a/generic/tcl.h	2026-05-03 13:19:00
@@ -59,7 +59,7 @@
 #define TCL_RELEASE_SERIAL  17
 
 #define TCL_VERSION	    "8.6"
-#define TCL_PATCH_LEVEL	    "8.6.17"
+#define TCL_PATCH_LEVEL	    "8.6.18a1"
 
 /*
  *----------------------------------------------------------------------------
diff -r -u tk8.6.17/generic/tk.h tk8.6.18a/generic/tk.h
--- tk8.6.17/generic/tk.h	2025-07-31 13:34:03
+++ tk8.6.18a/generic/tk.h	2026-05-03 13:25:04
@@ -78,7 +78,7 @@
 #define TK_RELEASE_SERIAL	17
 
 #define TK_VERSION		"8.6"
-#define TK_PATCH_LEVEL		"8.6.17"
+#define TK_PATCH_LEVEL		"8.6.18a1"

 /*
  * A special definition used to allow this header file to be included from
diff -r -u tk8.6.17/macosx/tkMacOSXWindowEvent.c tk8.6.18a/macosx/tkMacOSXWindowEvent.c
--- tk8.6.17/macosx/tkMacOSXWindowEvent.c	2025-07-31 13:34:03
+++ tk8.6.18a/macosx/tkMacOSXWindowEvent.c	2026-05-03 13:24:35
@@ -37,7 +37,8 @@
 
 #pragma mark TKApplication(TKWindowEvent)
 
-extern NSString *NSWindowDidOrderOnScreenNotification;
+/* disabled for Apple App Store Compliance */
+/* extern NSString *NSWindowDidOrderOnScreenNotification; */
 extern NSString *NSWindowWillOrderOnScreenNotification;
 
 #ifdef TK_MAC_DEBUG_NOTIFICATIONS
@@ -312,7 +313,8 @@
     observe(NSWindowDidMiniaturizeNotification, windowCollapsed:);
     observe(NSWindowWillMiniaturizeNotification, windowCollapsed:);
     observe(NSWindowWillOrderOnScreenNotification, windowMapped:);
-    observe(NSWindowDidOrderOnScreenNotification, windowBecameVisible:);
+    /* disabled for Apple App Store Compliance */
+    /* observe(NSWindowDidOrderOnScreenNotification, windowBecameVisible:); */
     observe(NSWindowWillStartLiveResizeNotification, windowLiveResize:);
     observe(NSWindowDidEndLiveResizeNotification, windowLiveResize:);
 
EOF
export CFLAGS="-arch x86_64 -arch arm64"
echo "Building tcl. This may take a while."
cd tcl8.6.17/macosx
make deploy install INSTALL_ROOT="${output_folder}" >>../../tcl-build.log 2>&1 || {
	echo "Error occurred building tcl. Check tcl-build.log."
	exit 1
}
cd ../../tk8.6.17/macosx
echo "Building tk. This may take a while."
make deploy install INSTALL_TARGETS='install-binaries install-libraries install-headers install-private-headers' INSTALL_ROOT="${output_folder}" >>../../tk-build.log 2>&1 || {
	echo "Error occurred building tk. Check tk-build.log."
	exit 1
}
cd ../..
echo "tcl and tk built successfully. Installing in Python frameworks directory."

backup_path="${framework_path}/backups/$(date +'%Y-%m-%d-%H-%M-%S')"
tcl_path="${framework_path}/Tcl.framework"
tk_path="${framework_path}/Tk.framework"
[ -n "${tcl_path}" ] && [ -n "${tk_path}" ] || {
	echo "Could not find existing Tcl/Tk paths under ${framework_path}. If Python is installed elsewhere, please re-run this script with the the path to its 'Frameworks' folder."
	exit 1
}
[ -d "${tk_path}" ] || {
	echo "Could not find ${tk_path}. If Python is installed elsewhere, please re-run this script with the the path to its 'Frameworks' folder."
	exit 1
}
echo "Found tk in ${tk_path}."
[ -d "${tcl_path}" ] || {
	echo "Could not find ${tcl_path}. If Python is installed elsewhere, please re-run this script with the the path to its 'Frameworks' folder."
	exit 1
}
[ -e "${output_folder}/Library/Frameworks/Tk.framework/Versions/8.6/Tk" ] && [ -e "${output_folder}/Library/Frameworks/Tcl.framework/Versions/8.6/Tcl" ] || {
	echo "Tk/Tcl output not built as expected in ${output_folder}/Library/Frameworks/. Check build logs and try again."
	exit 1
}
echo "Found tcl in ${tcl_path}."
echo "Installing patched Tk and Tcl into ${framework_path}. This requires sudo privileges, so you may be prompted for your password."
echo "Backing up current Tk and Tcl Python frameworks to ${backup_path}. These can be deleted manually if you like."
sudo mkdir -p "${backup_path}"
sudo cp -R "${tk_path}" "${tcl_path}" "${backup_path}" || {
	echo "Backup failed. Exiting."
	exit 1
}
echo "Backup successful. Updating dylib paths."
sudo install_name_tool -id "${tk_path}/Tk" "${output_folder}/Library/Frameworks/Tk.framework/Versions/8.6/Tk"
sudo install_name_tool -id "${tcl_path}/Tcl" "${output_folder}/Library/Frameworks/Tcl.framework/Versions/8.6/Tcl"
echo "Replacing Tk and Tcl with patched versions."
sudo rm -rf "${tcl_path}" "${tk_path}"
sudo cp -R "${output_folder}/Library/Frameworks/Tk.framework" "${output_folder}/Library/Frameworks/Tcl.framework" "${framework_path}" || {
	echo "Copy failed. Exiting."
	exit 1
}
echo "Signing patched Tk and Tcl."
sudo codesign --force --deep --sign - "${tcl_path}" || echo "Tcl signing failed."
sudo codesign --force --deep --sign - "${tk_path}" || echo "Tk signing failed."
echo "Testing if tkinter still works and reporting patchlevel; you should see 8.6.18a1 if everything was successful:"
python3 -c "import tkinter; print(tkinter.Tcl().eval('info patchlevel'))"
