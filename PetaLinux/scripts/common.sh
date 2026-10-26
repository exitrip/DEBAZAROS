# common.sh - sourced by the other scripts. PetaLinux 2022.2 on Ubuntu 22.04.
#   PLNX_SETTINGS  PetaLinux install (default ~/petalinux/2022.2/settings.sh)
#   PLNX_PROJECT   the PetaLinux project (default: the folder above scripts/)
#   PLNX_CACHE     backup of downloads + sstate (default ~/petalinux-2022.2-cache)
PLNX_SETTINGS=${PLNX_SETTINGS:-$HOME/petalinux/2022.2/settings.sh}
PLNX_PROJECT=${PLNX_PROJECT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
PLNX_CACHE=${PLNX_CACHE:-$HOME/petalinux-2022.2-cache}
