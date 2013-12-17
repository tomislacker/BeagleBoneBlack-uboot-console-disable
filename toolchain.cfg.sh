#!/bin/bash

THIS_SCRIPT=`readlink -f "$0"`
THIS_DIR=`dirname "${THIS_SCRIPT}"`
LOG_DATE_FORMAT="%Y-%m-%d %H%M%S %Z"
TAB_INDENT=0
LOG_OUTPUT=`date +%s`.log
LOG_DEBUG=`date +%s`-debug.log

ARM_CC_URL="https://launchpad.net/linaro-toolchain-binaries/trunk/2013.10/+download/gcc-linaro-arm-linux-gnueabihf-4.8-2013.10_linux.tar.xz"
ARM_CC_FILE=`echo "$ARM_CC_URL" | sed 's/^.*\///'`

ARM_CC_ASC_URL="${ARM_CC_URL}.asc"
ARM_CC_ASC_FILE=`echo "$ARM_CC_ASC_URL" | sed 's/^.*\///'`

ARM_CC_GPG_KEY=8F427EAF
ARM_CC_GPG_SERVER=pgpkeys.mit.edu

UBOOT_REPO_URL=git://git.denx.de/u-boot.git
UBOOT_REPO_BASE_BRANCH=master
UBOOT_REPO_TEMP_BRANCH=tmp

EEWIKI_PATCH_URL="https://raw.github.com/eewiki/u-boot-patches/master/v2013.10/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
EEWIKI_PATCH_FILE=`echo "$EEWIKI_PATCH_URL" | sed 's/^.*\///'`

cd "$THIS_DIR"

