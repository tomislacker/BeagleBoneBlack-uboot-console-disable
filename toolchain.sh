#!/bin/bash

cat << EOF
#########################################################
# Beagle U-Boot (Universal Boot Loader) Patch Toolchain #
#########################################################
# This program is necessary because the 'stock' U-Boot  #
# will allow the Beagle to go the u-boot console if the #
# UART0 pin is high.  This toolchain (and subsequent    #
# patch) will make the Beagle only enter the u-boot     #
# console if a specific string of keys is entered. This #
# will ensure that, upon a reboot, the Beagle should    #
# not get stuck at the console.                         #
#########################################################
#    Notes   #
##############
# - Ensure you have 32bit CPP support
#   Debian: apt-get install ia32-libs
#   Gentoo: emerge -av emul-linx-x86-{baselibs,db,compat,cpplibs}
# References #
##############
# 1. https://www.mail-archive.com/beagleboard@googlegroups.com/msg02050.html
# 2. http://eewiki.net/display/linuxonarm/BeagleBone+Black#BeagleBoneBlack-Bootloader:U-Boot
# 3. http://www.denx.de/wiki/U-Boot
##############
EOF

. "`dirname "\`readlink -f "$0"\`"`/toolchain.cfg.sh"
. "`dirname "\`readlink -f "$0"\`"`/toolchain.inc.sh"

#####
# 1) Fetch and extract the ARM Cross Compiler: GCC
#####
logMessage "Setting up ARM Cross Compiler" && indentMore

###
# 1.a) Install GPG key for the GCC source
###
ARM_CC_SKIP_GPG=no
logMessage "Install GPG Key (${ARM_CC_GPG_KEY}) from ${ARM_CC_GPG_SERVER}" && indentMore
gpg --keyserver $ARM_CC_GPG_SERVER --recv-key $ARM_CC_GPG_KEY >>/dev/null 2>&1 \
    && logMessage "Success" \
    || ( logMessage "Failed - Continuing without GPG verification..." && ARM_CC_SKIP_GPG=yes )
indentLess

###
# 1.b) Download and verify the compiler tarball
###
ARM_CC_DIR="`pwd`/`basename "${ARM_CC_FILE}" .tar.xz`"
if [ -d "${ARM_CC_DIR}" ]; then
    logMessage "ARM Cross Compiler Already Downloaded and Extracted"
else
    logMessage "Downloading ARM Cross Compiler" && indentMore

    #
    # 1.b.1) tarball (.xz)
    #
    if [ ! -f "${ARM_CC_FILE}" ]; then
        logMessage "${ARM_CC_FILE} ..." && indentMore
        curl --silent -LO "${ARM_CC_URL}" \
            && logMessage "Success" \
            || logMessage "Failed" >&2
        indentLess
    fi

    #
    # 1.b.2) .asc file
    #
    if [ ! -f "${ARM_CC_ASC_FILE}" -a "${ARM_CC_SKIP_GPG}" != "yes" ]; then
        logMessage "${ARM_CC_ASC_FILE} ..." && indentMore
        curl --silent -LO "${ARM_CC_ASC_URL}" \
            && logMessage "Success" \
            || logMessage "Failed" >&2
        indentLess
    fi
    indentLess

    #
    # 1.b.3) Verification (GPG)    
    #
    if [ -f "${ARM_CC_FILE}" -a "${ARM_CC_SKIP_GPG}" != "yes" ]; then
        # We have the tarball downloaded and we want to verify the integrity
        logMessage "Verifying Contents..." && indentMore
        if [ -f "${ARM_CC_ASC_FILE}" ]; then
            gpg "${ARM_CC_ASC_FILE}" >>/dev/null 2>&1 \
                && logMessage "GPG Verification Successful" \
                || fatalMessage 90 "GPG Verification Failed - Signature Mismatch"
        else
            fatalMessage 91 "GPG Verification Failed - .asc file does not exist"
        fi
        indentLess
    fi

    #
    # 1.b.4) Extraction
    #
    logMessage "Extracting and Testing" && indentMore

    tar -xJf "${ARM_CC_FILE}" \
        && logMessage "Extracting Completed" \
        && fatalMessage 92 "Extraction Failed"
    
    indentLess
fi

###
# 1.c) Test compiler
###
export CC="`pwd`/`basename "${ARM_CC_FILE}" .tar.xz`/bin/arm-linux-gnueabihf-"
logMessage "Exporting CC='${CC}'" && indentMore
${CC}gcc --version >>/dev/null 2>&1 \
    && logMessage "Cross Compiler Setup - `${CC}gcc --version |head -1`" \
    || fatalMessage 93 "Cross Compiler Setup Failed `${CC}gcc --version 2>&1`"
indentLess

#####
# /1
#####
indentLess

#####
# 2) Fetch and/or maintain the u-boot repository
#####
logMessage "Cloning/updating u-boot git repository" && indentMore
if [ -d "${THIS_DIR}/u-boot" ]; then
	#####
	# 2.a) The repository is already present locally.  Ensure that we're
	# pointed at the $UBOOT_REPO_BASE_BRANCH branch, the 'tmp' branch does
	# not exist (as we're going to build our patch in there), and we attempt
	# to pull any updates to the repo.
	#####
	cd "${THIS_DIR}/u-boot"

	###
	# 2.a.1) Ensure we're on the $UBOOT_REPO_BASE_BRANCH branch
	###
	if [ "$(gitGetCurrentBranch)" != "${UBOOT_REPO_BASE_BRANCH}" ]; then
		logMessage "Currently on branch '$(gitGetCurrentBranch)', changing to '${UBOOT_REPO_BASE_BRANCH}'" && indentMore
		git checkout -fq ${UBOOT_REPO_BASE_BRANCH} >>/dev/null 2>&1 \
			&& logMessage "Changed to '${UBOOT_REPO_BASE_BRANCH}'" \
			|| fatalMessage 101 "Failed to change to '${UBOOT_REPO_BASE_BRANCH}' :: `pwd` :: git checkout v2013.10 ${UBOOT_REPO_BASE_BRANCH}"
		indentLess
	else
		logMessage "Currently on branch '$(getGetCurrentBranch)'"
	fi

	###
	# 2.a.2) If the 'tmp' branch exists, remove it because that's where we're
	# going to build out tools out at
	###
	if gitBranchExists tmp; then
		logMessage "Branch 'tmp' exists, attempting removal" && indentMore
		git branch -D tmp >>/dev/null 2>&1 \
			&& logMessage "Removed 'tmp' branch" \
			|| fatalMessage 102 "Failed to remove 'tmp' branch"
		indentLess
	else
		logMessage "Branch 'tmp' does not exist (Good thing)"
	fi

	###
	# 2.a.3) Attempt a pull to grab any updates to the repository
	###
	logMessage "Attempting pull" && indentMore
	git pull -q >>/dev/null 2>&1 \
		&& logMessage "Success pulled updates" \
		|| fatalMessage 103 "Failed to pull updates"
	indentLess
else
	#####
	# 1.b) We have never cloned the repository locally.  Do so now.
	#####
	logMessage "Attempting to clone (${UBOOT_REPO_URL})" && indentMore
	git clone -q $UBOOT_REPO_URL >>/dev/null 2>&1 \
		&& logMessage "Successfully cloned repo" \
		|| fatalMessage 104 "FAILED to clone repo"
	indentLess
fi
#####
# /2
#####
indentLess

#####
# 3) Branch and patch the repo
#####

###
# 3.a) Branch from $UBOOT_REPO_BASE_BRANCH to $UBOOT_REPO_TEMP_BRANCH
###
logMessage "Branching u-boot ${UBOOT_REPO_BASE_BRANCH} -> ${UBOOT_REPO_TEMP_BRANCH}" && indentMore
cd "${THIS_DIR}/u-boot"
git checkout v2013.10 -qfb ${UBOOT_REPO_TEMP_BRANCH} \
	&& logMessage "Branched successfully ${UBOOT_REPO_BASE_BRANCH} -> ${UBOOT_REPO_TEMP_BRANCH}" \
	|| fatalMessage 105 "Failed to branch ${UBOOT_REPO_BASE_BRANCH} -> ${UBOOT_REPO_TEMP_BRANCH}"
indentLess

###
# 3.b) Download the first patch file
###
logMessage "Downloading and applying eewiki/u-boot-patches" && indentMore

#
# 3.b.1) Download the patch file
#
logMessage "Downloading patch (${EEWIKI_PATCH_URL})" && indentMore
curl --silent -LO "${EEWIKI_PATCH_URL}" \
	&& logMessage "Successfully downloaded" \
	|| fatalMessage 106 "Failed to download ${EEWIKI_PATCH_URL}"
indentLess

#
# 3.b.2) Apply the patch file
#
logMessage "Applying patch file (${EEWIKI_PATCH_FILE})" && indentMore
patch -p1 < $EEWIKI_PATCH_FILE \
	&& logMessage "Successfully patched" \
	|| fatalMessage 107 "FAILED: patch -p1 < $EEWIKI_PATCH_FILE"
indentLess

#####
# /3
#####
indentLess

#####
# 4) Configure and build the new u-boot
#####
logMessage "Configuring and building u-boot" && indentMore

###
# 4.a) distclean
###
logMessage "[make] target=distclean" && indentMore
make ARCH=arm CROSS_COMPILE=${CC} distclean >toolchain.make1.log \
    && logMessage "Success" \
    || fatalMessage 108 "FAILED"
indentLess

###
# 4.b) config
###
logMessage "[make] target=am335x_evm_config" && indentMore
make ARCH=arm CROSS_COMPILE=${CC} am335x_evm_config >toolchain.make2.log \
    && logMessage "Success" \
    || fatalMessage 109 "FAILED"
indentLess

###
# 4.c) Add specific config parameters
#   CONFIG_AUTOBOOT_KEYED 1 
#   CONFIG_AUTOBOOT_DELAY_STR "uboot"
# @see https://www.mail-archive.com/beagleboard@googlegroups.com/msg02050.html
###
logMessage "[config] Patching AUTOBOOT params" && indentMore
egrep "^#define\s+CONFIG_AUTOBOOT_KEYED\s+" include/config.h >>/dev/null 2>&1 \
    && sed -i 's/^#define\s\+CONFIG_AUTOBOOT_KEYED.*$/#define CONFIG_AUTOBOOT_KEYED 1/' include/config.h \
    || echo '#define CONFIG_AUTOBOOT_KEYED 1' | tee -a include/config.h >>/dev/null
egrep "^#define\s+CONFIG_AUTOBOOT_DELAY_STR\s+" include/config.h >>/dev/null 2>&1 \
    && sed -i 's/^#define\s\+CONFIG_AUTOBOOT_DELAY_STR.*$/#define CONFIG_AUTOBOOT_DELAY_STR "uboot"/' include/config.h \
    || echo '#define CONFIG_AUTOBOOT_DELAY_STR "uboot"' | tee -a include/config.h >>/dev/null
indentLess

###
# 4.d) build
###
logMessage "[make] Final Build" && indentMore
make ARCH=arm CROSS_COMPILE=${CC} >>toolchain.make3.log \
    && logMessage "Success" \
    || fatalMessage 110 "FAILED"
indentLess

#####
# /4
#####
indentLess

#####
# All Done
#####
logMessage "All Done"
exit 0

