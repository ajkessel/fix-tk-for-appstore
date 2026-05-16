# fix-tk-for-appstore

## What?

Patches and replaces tcl and tk on MacOS to compile Python applications with pyinstaller that will be accepted by the App Store.

## Why?

This is necessary because tcl8.6 includes a reference to NSWindowDidOrderOnScreenNotification which is a deprecated API. It does not appear to be used by Tk for MacOS 26 so can be commented out. Note this may not work with older MacOS versions.

## How?

This script assumes:

- You are using universal2 Python from python.org, installed in `/Library/Frameworks/Python.framework`
- Your Python depends on tcl/tk 8.6.17

If you are using a different version of Python or tcl/tk, this script may be adapted for the purpose, but I've only tested it with these conditions.

## Usage

Just execute `fix-tk-for-appstore.sh`. sudo (administrator) rights are necessary to replace the files under `/Library/Frameworks/Python.framework`

Two switches are provided:
- `-c` for "clean": delete prior build artifacts
- an alternate path for your Python installation; just specify the path on the command line
