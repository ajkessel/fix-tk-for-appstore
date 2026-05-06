#!/usr/bin/env bash
echo "Usage: ${0} [-c] [path to Python frameworks]"
printf "\nThis script fixes Python tcl/tk so that an application built with pyinstaller can be submitted to the App Store."
echo "This is necessary because tcl8.6.0-9.0.4 include a reference to NSWindowDidOrderOnScreenNotification which is a deprecated API. It does not appear to be used by Tk so can be commented out."
echo "See https://core.tcl-lang.org/tk/tktview/a9969f7ffd966229c4e6 for more details."
echo "-c cleans the working folder and deletes past build artifacts and downoaded files"
printf "[path to Python frameworks] is the path to your working copy of Python's Frameworks directory; default is /Library/Frameworks/Python.framework/Versions/Current/Frameworks\n\n"
version=$(python3 -c "import tkinter; print(tkinter.TkVersion)")
patchlevel=$(python3 -c "import tkinter; print(tkinter.Tcl().eval('info patchlevel'))")
if [ -z "${version}" ] || [ -z "${patchlevel}" ] || ! [[ "${patchlevel}" =~ ^[8-9]\.[0-9]+\.[0-9]+ ]]; then
  echo 'Could not extract Tcl/Tk version and patchlevel strings. Make sure python3 is installed with tk/tcl support and in path.'
  echo 'Run this command to test:'
  echo "python3 -c \"import tkinter; print(tkinter.Tcl().eval('info patchlevel'))\""
  exit 1
fi
echo "Found tcl/tk version ${version}, patchlevel ${patchlevel}."
framework_path=$(realpath '/Library/Frameworks/Python.framework/Versions/Current/Frameworks')
output_folder=$(mktemp -d -t fix-tk.xxxx)
echo "tcl/tk will be temporarily installed in ${output_folder}. This can be safely deleted after a successful run."
[ "${1}" == "-c" ] && shift && rm -rf "tcl${patchlevel}" "tcl${patchlevel}-src.tar.gz" "tk${patchlevel}" tk${patchlevel}-src.tar.gz build && echo 'Prior build artifacts removed.'
[ -n "${1}" ] && framework_path="${1}"
echo "Downloading tcl and tk from sourceforge into current directory."
[ -e "tcl${patchlevel}-src.tar.gz" ] || curl -L -sS -o tcl${patchlevel}-src.tar.gz "https://downloads.sourceforge.net/project/tcl/Tcl/${patchlevel}/tcl${patchlevel}-src.tar.gz"
[ -e "tk${patchlevel}-src.tar.gz" ] || curl -L -sS -o tk${patchlevel}-src.tar.gz "https://downloads.sourceforge.net/project/tcl/Tcl/${patchlevel}/tk${patchlevel}-src.tar.gz"
tar xfz tcl${patchlevel}-src.tar.gz || {
	echo 'Extracting of tcl source code failed. Exiting.'
	exit 1
}
tar xfz tk${patchlevel}-src.tar.gz || {
	echo 'Extracting of tk source code failed. Exiting.'
	exit 1
}
[ -e tcl${patchlevel}/macosx/GNUmakefile ] && [ -e tk${patchlevel}/macosx/GNUmakefile ] || {
	echo 'GNUmakefile not found. Something went wrong. Exiting.'
	exit 1
}
echo "Patching source code to comment out references to NSWindowDidOrderOnScreenNotification."
[ ! -f "tk${patchlevel}/macosx/tkMacOSXWindowEvent.c" ] && {
  echo "Could not find tk${patchlevel}/macosx/tkMacOSXWindowEvent.c to patch. Exiting."
  exit 1
}
cp "tk${patchlevel}/macosx/tkMacOSXWindowEvent.c" "tk${patchlevel}/macosx/tkMacOSXWindowEvent.c.orig"
perl -p -i -e 's/^(.*NSWindowDidOrderOnScreenNotification.*)$/ \/* $1 *\//g' "tk${patchlevel}/macosx/tkMacOSXWindowEvent.c"
if [ "$?" != "0" ]; then
  echo "Error occurred with patch. Exiting."
  exit 1
fi
echo "Change applied:"
diff -u "tk${patchlevel}/macosx/tkMacOSXWindowEvent.c.orig" "tk${patchlevel}/macosx/tkMacOSXWindowEvent.c"
if [ "$?" == "0" ]; then 
  echo "No changes made because NSWindowDidOrderOnScreenNotification was not found in tkMacOSXWindowEvent.c. Was this file already patched?"
  exit 1
fi
export CFLAGS="-arch x86_64 -arch arm64"
echo "Building tcl. This may take a while."
cd tcl${patchlevel}/macosx
make deploy install INSTALL_ROOT="${output_folder}" >>../../tcl-build.log 2>&1 || {
	echo "Error occurred building tcl. Check tcl-build.log."
	exit 1
}
cd ../../tk${patchlevel}/macosx
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
[ -e "${output_folder}/Library/Frameworks/Tk.framework/Versions/${version}/Tk" ] && [ -e "${output_folder}/Library/Frameworks/Tcl.framework/Versions/${version}/Tcl" ] || {
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
echo "Replacing Tk and Tcl with patched patchlevels."
sudo rm -rf "${tcl_path}" "${tk_path}"
sudo cp -R "${output_folder}/Library/Frameworks/Tk.framework" "${output_folder}/Library/Frameworks/Tcl.framework" "${framework_path}" || {
	echo "Copy failed. Exiting."
	exit 1
}
echo "Signing patched Tk and Tcl."
sudo codesign --force --deep --sign - "${tcl_path}" || echo "Tcl signing failed."
sudo codesign --force --deep --sign - "${tk_path}" || echo "Tk signing failed."
echo "Testing if tkinter still works and reporting patchlevel; you should see ${patchlevel} if everything was successful:"
python3 -c "import tkinter; print(tkinter.Tcl().eval('info patchlevel'))"
