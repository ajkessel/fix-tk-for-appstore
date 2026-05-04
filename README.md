# fix-tk-for-appstore

## Why?

Patches and replaces tcl and tk on MacOS to compile Python applications with pyinstaller that will be accepted by the App Store.

This is necessary because tcl8.6 includes a reference to NSWindowDidOrderOnScreenNotification which is a deprecated API. It does not appear to be used by Tk so can be commented out.

This script assumes:

- You are using universal2 Python from python.org, installed in `/Library/Frameworks/Python.framework`
- Your Python depends on tcl/tk 8.6.17

## Usage

Just execute `fix-tk-for-appstore.sh`. sudo (administrator) rights are necessary to replace the files under `/Library/Frameworks/Python.framework`

Two switches are provided:
- `-c` for "clean": delete prior build artifacts
- an alternate path for your Python installation; just specify the path on the command line
