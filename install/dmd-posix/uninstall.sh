#!/bin/bash

# A simple script to uninstall Tango for DMD
# Copyright (C) 2007  Gregor Richards
# Permission is granted to do anything you please with this software.
# This software is provided with no warranty, express or implied, within the
# bounds of applicable law.
#
# Modifications by Alexander Panek, Lars Ivar Igesund

die() {
    echo "$1"
    exit $2
}

usage() {
    echo 'Usage: tango-dmd-tools.sh <command>'
    echo '    --uninstall <install prefix> - uninstalls previous Tango install'
    exit 0
}

if [ "$#" = "0" ]
then
    usage
else
    if [ "$1" = "--uninstall" ]
    then
        if [ "$2" ]
        then
            PREFIX="$2"
        else
            usage
        fi
    else
        usage
    fi
fi

cd "`dirname $0`"
dmd --help >& /dev/null || die "dmd not found on your \$PATH!" 1

# revert to phobos if earlier evidence of existense is found
if [ -e "$PREFIX/lib/libphobos.a.phobos" ]
then
    mv     $PREFIX/lib/libphobos.a.phobos $PREFIX/lib/libphobos.a
fi
if [ -e "$PREFIX/import/object.d.phobos" ]
then
    mv     $PREFIX/import/object.d.phobos $PREFIX/import/object.d
fi
if [ -e "$PREFIX/bin/dmd.conf.phobos" ]
then
    mv   $PREFIX/bin/dmd.conf $PFEFIX/bin/dmd.conf.tango
    mv   $PREFIX/bin/dmd.conf.phobos $PREFIX/bin/dmd.conf
fi
# Tango 0.97 installed to this dir
if [ -e "$PREFIX/import/v1.012" ]
then
    rm -rf $PREFIX/import/v1.012
fi
# Since Tango 0.98
if [ -e "$PREFIX/import/tango/object.di" ]
then
    rm -rf $PREFIX/import/tango/tango
    rm -rf $PREFIX/import/tango/std
    rm -f  $PREFIX/import/tango/object.di
fi
if [ -e "$PREFIX/lib/libtango.a" ]
then
    rm -f $PREFIX/lib/libtango.a
fi
die "Done!" 0

