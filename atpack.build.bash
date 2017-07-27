#!/bin/bash -ex
# Copyright (c) 2017 Arduino LLC
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

mkdir -p atpack
cd atpack
rm -rf *
mv ../*.atpack .

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
  cp -r gcc/dev/${folder}/* temp/
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

