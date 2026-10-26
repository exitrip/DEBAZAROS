# bitbake-env.sh - source me: the bitbake environment petalinux-build uses,
# for bitbake options that petalinux-build cannot pass (it turns every word
# of -x into a separate -c task). Example:
#   ( source scripts/bitbake-env.sh && bitbake petalinux-image-minimal --runall=fetch )
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$PLNX_SETTINGS" >/dev/null
source "$(dirname "$PLNX_SETTINGS")"/components/yocto/buildtools/environment-setup-x86_64-petalinux-linux
cd "$PLNX_PROJECT/components/yocto" && source ./environment-setup-cortexa9t2hf-neon-xilinx-linux-gnueabi >/dev/null
source ./layers/core/oe-init-build-env "$PLNX_PROJECT/build" >/dev/null
