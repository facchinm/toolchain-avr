#!/bin/bash -ex
# Copyright (c) 2014-2016 Arduino LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

source build.conf

OUTPUT_VERSION=${GCC_VERSION}-atmel${AVR_VERSION}-${BUILD_NUMBER}

export OS=`uname -o || uname`
export TARGET_OS=$OS

if [[ $CROSS_COMPILE == "mingw" ]] ; then

  export CC="i686-w64-mingw32-gcc"
  export CXX="i686-w64-mingw32-g++"
  export CROSS_COMPILE_HOST="i686-w64-mingw32"
  export TARGET_OS="Windows"
  OUTPUT_TAG=i686-w64-mingw32

elif [[ $OS == "GNU/Linux" ]] ; then

  export MACHINE=`uname -m`
  if [[ $MACHINE == "x86_64" ]] ; then
    OUTPUT_TAG=x86_64-pc-linux-gnu
  elif [[ $MACHINE == "i686" ]] ; then
    OUTPUT_TAG=i686-pc-linux-gnu
  elif [[ $MACHINE == "armv7l" ]] ; then
    OUTPUT_TAG=armhf-pc-linux-gnu
  else
    echo Linux Machine not supported: $MACHINE
    exit 1
  fi

elif [[ $OS == "Msys" || $OS == "Cygwin" ]] ; then

  export PATH=$PATH:/c/MinGW/bin/:/c/cygwin/bin/
  export CC="mingw32-gcc -m32"
  export CXX="mingw32-g++ -m32"
  export CFLAGS="-DWIN32 -D__USE_MINGW_ACCESS"
  export CXXFLAGS="-DWIN32"
  export LDFLAGS="-DWIN32"
  export MAKE_JOBS=1
  OUTPUT_TAG=i686-mingw32

elif [[ $OS == "Darwin" ]] ; then

  export PATH=/opt/local/libexec/gnubin/:/opt/local/bin:$PATH
  export CC="gcc -arch i386 -mmacosx-version-min=10.5"
  export CXX="g++ -arch i386 -mmacosx-version-min=10.5"
  OUTPUT_TAG=i386-apple-darwin11

else

  echo OS Not supported: $OS
  exit 2

fi

rm -rf autoconf-${AUTOCONF_VERSION} automake-${AUTOMAKE_VERSION}
rm -rf gcc gmp-${GMP_VERSION} mpc-${MPC_VERSION} mpfr-${MPFR_VERSION} binutils avr-libc libc avr8-headers gdb
rm -rf toolsdir objdir *-build

./tools.bash
./binutils.build.bash
./gcc.build.bash
./avr-libc.build.bash
./gdb.build.bash

rm -rf objdir/{info,man,share}

#add extra files from atpack (only use the neede ones
mkdir -p atpack
cd atpack
rm -rf *
if [[ ! -f *.atpack ]] ;
then
        wget ${ATMEL_ATMEGA_PACK_URL}
fi

mv ${ATMEL_ATMEGA_PACK_FILENAME}.atpack ${ATMEL_ATMEGA_PACK_FILENAME}.zip
unzip ${ATMEL_ATMEGA_PACK_FILENAME}.zip

#copy relevant files to the right folders
# 1- copy includes definitions
EXTRA_INCLUDES=`diff -q ../objdir/avr/include/avr ../atpack/include/avr | grep "Only in" | grep atpack | cut -f4 -d" "`
for x in $EXTRA_INCLUDES; do
cp include/avr/$x ../objdir/avr/include/avr
done

# 2 - compact specs into a single folder
SPECS_FOLDERS=`ls gcc/dev`
mkdir temp
for folder in $SPECS_FOLDERS; do
cp -r gcc/dev/i${folder}/* temp/
done

# 3 - find different files (device-specs)
EXTRA_SPECS=`diff -q ../objdir/lib/gcc/avr/${GCC_VERSION}/device-specs/ temp/device-specs | grep "Only in" | grep temp | cut -f4 -d" "`
for x in $EXTRA_SPECS; do
cp temp/device-specs/${x} ../objdir/lib/gcc/avr/${GCC_VERSION}/device-specs/
done

rm -rf temp/device-specs

EXTRA_LIBS=`diff -q ../objdir/avr/lib temp/ | grep "Only in" | grep temp | cut -f4 -d" "`
for x in $EXTRA_LIBS; do
cp -r temp/${x} ../objdir/avr/lib/${x}
done

# 4 - extract the correct includes and add them to io.h
# ARGH! difficult!
for x in $EXTRA_SPECS; do
DEFINITION=`cat ../objdir/lib/gcc/avr/${GCC_VERSION}/device-specs/${x} | grep __AVR_DEVICE_NAME__ | cut -f1 -d" " | cut -f2 -d"D"`
FANCY_NAME=`cat ../objdir/lib/gcc/avr/${GCC_VERSION}/device-specs/${x} | grep __AVR_DEVICE_NAME__ | cut -f2 -d"="`
LOWERCASE_DEFINITION="${DEFINITION,,}"
HEADER_TEMP="${LOWERCASE_DEFINITION#__avr_atmega}"
HEADER="${HEADER_TEMP%__}"
_DEFINITION="#elif defined (${DEFINITION})"
_HEADER="#   include <avr/iom${HEADER}.h>"
awk '/iom3000.h/ { print; print "_DEFINITION"; print "_HEADER"; next }1' ../objdir/avr/include/avr/io.h | sed "s/_DEFINITION/$_DEFINITION/g" |  sed "s@_HEADER@$_HEADER@g" > ../objdir/avr/include/avr/io.h
done

cd ..

# if producing a windows build, compress as zip and
# copy *toolchain-precompiled* content to any folder containing a .exe
if [[ ${OUTPUT_TAG} == *"mingw"* ]] ; then

  rm -f avr-gcc-${OUTPUT_VERSION}-${OUTPUT_TAG}.zip
  mv objdir avr
  BINARY_FOLDERS=`find avr -name *.exe -print0 | xargs -0 -n1 dirname | sort --unique`
  echo $BINARY_FOLDERS | xargs -n1 cp toolchain-precompiled/*
  zip -r avr-gcc-${OUTPUT_VERSION}-${OUTPUT_TAG}.zip avr
  mv avr objdir

else

  rm -f avr-gcc-${OUTPUT_VERSION}-${OUTPUT_TAG}.tar.bz2
  mv objdir avr
  tar -cjvf avr-gcc-${OUTPUT_VERSION}-${OUTPUT_TAG}.tar.bz2 avr
  mv avr objdir

fi
