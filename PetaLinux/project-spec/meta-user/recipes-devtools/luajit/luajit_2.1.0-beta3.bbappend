# luajit.org no longer serves release tarballs, and LuaJIT has no git tags
# any more (rolling releases): the meta-petalinux recipe cannot fetch
# http://luajit.org/download/LuaJIT-2.1.0-beta3.tar.gz. Fetch the same
# release from git instead: commit 8271c643 = "RELEASE LuaJIT-2.1.0-beta3"
# (2017-05-01; its Makefile says 2.1.0-beta3), so the recipe's patch and
# file names still match. (DEBAZAROS, 2026-10-25)
SRC_URI:remove = "http://luajit.org/download/LuaJIT-${PV}.tar.gz"
SRC_URI:prepend = "git://github.com/LuaJIT/LuaJIT.git;protocol=https;branch=v2.1 "
SRCREV = "8271c643c21d1b2f344e339f559f2de6f3663191"
S = "${WORKDIR}/git"
