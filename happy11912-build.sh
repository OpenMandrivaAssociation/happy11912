#!/bin/bash
# Boot compiler is the installed ghc88 RPM (numeric-version 8.8.4). The
# final happy is configured again with --prefix=/usr so Paths_happy
# getDataDir is /usr/share/x86_64-linux-ghc-8.8.4/happy-1.19.12. The
# script's prefix is a work directory it removes; it must not be /usr.
set -euo pipefail

ROOT=${1:?usage: happy11912-build.sh ROOT LIBDIR}
LIBDIR=${2:?}
# GHC 8.8 links the system GMP. LIBDIR is only the shared driver argument.
: "$LIBDIR"
export STAGE="$ROOT"
export TMPDIR="$ROOT/tmp"
mkdir -p "$TMPDIR"
unset CFLAGS CXXFLAGS LDFLAGS CPPFLAGS RPM_OPT_FLAGS RPM_LD_FLAGS || true
unset LD_LIBRARY_PATH || true
unset GHC_PACKAGE_PATH || true
ulimit -s unlimited 2>/dev/null || true

fail() { printf 'happy11912: %s\n' "$*" >&2; exit 1; }

IN=$ROOT/incoming
[ -d "$IN" ] || fail "missing $IN"
[ -f "$IN/happy-1.19.12.tar.gz" ] || fail "happy tarball missing"
[ -f "$IN/happy-1.19.12-tag.tar.gz" ] || fail "tag tarball missing"
[ -x /usr/bin/ghc88 ] || fail "/usr/bin/ghc88 missing"
[ -x /usr/bin/ghc-pkg88 ] || fail "/usr/bin/ghc-pkg88 missing"
[ -x /usr/bin/happy1195 ] || fail "/usr/bin/happy1195 missing"
[ -x /usr/bin/cpphs-mhs ] || fail "/usr/bin/cpphs-mhs missing"

mkdir -p "$ROOT/build/sources" \
	"$ROOT/build/ref-ghc-bootstrap/ghc66" \
	"$ROOT/build/ghc88-work/ghc88-prefix/bin" \
	"$ROOT/build/ghc74-tools/happy-1.19.5-prefix/bin"

cp -a "$IN/happy-1.19.12.tar.gz" "$ROOT/build/sources/happy-1.19.12.tar.gz"
tar -C "$ROOT/build/sources" -xzf "$IN/happy-1.19.12-tag.tar.gz"
[ -f "$ROOT/build/sources/happy-1.19.12-tag/src/Parser.ly" ] || fail "tag Parser.ly missing"
[ -f "$ROOT/build/sources/happy-1.19.12-tag/src/AttrGrammarParser.ly" ] || fail "tag AttrGrammarParser.ly missing"
[ -f "$ROOT/build/sources/happy-1.19.12-tag/templates/GenericTemplate.hs" ] || fail "tag GenericTemplate.hs missing"
[ -f "$ROOT/build/sources/happy-1.19.12-tag/templates/GLR_Base.hs" ] || fail "tag GLR_Base.hs missing"
[ -f "$ROOT/build/sources/happy-1.19.12-tag/templates/GLR_Lib.hs" ] || fail "tag GLR_Lib.hs missing"
cp -a "$IN/cpp-template.sh" "$ROOT/build/ref-ghc-bootstrap/ghc66/cpp-template.sh"
cp -a "$IN/cmp-generated.sh" "$ROOT/build/ref-ghc-bootstrap/ghc66/cmp-generated.sh"
chmod 755 "$ROOT/build/ref-ghc-bootstrap/ghc66/cpp-template.sh" \
	"$ROOT/build/ref-ghc-bootstrap/ghc66/cmp-generated.sh"

cat > "$ROOT/build/ghc88-work/ghc88-prefix/bin/ghc" << 'EOF'
#!/bin/sh
exec /usr/bin/ghc88 "$@"
EOF
cat > "$ROOT/build/ghc88-work/ghc88-prefix/bin/ghc-pkg" << 'EOF'
#!/bin/sh
exec /usr/bin/ghc-pkg88 "$@"
EOF
chmod 755 "$ROOT/build/ghc88-work/ghc88-prefix/bin/ghc" \
	"$ROOT/build/ghc88-work/ghc88-prefix/bin/ghc-pkg"
ln -sfn /usr/bin/happy1195 "$ROOT/build/ghc74-tools/happy-1.19.5-prefix/bin/happy"

export PATH="$ROOT/build/ghc88-work/ghc88-prefix/bin:$ROOT/build/ghc74-tools/happy-1.19.5-prefix/bin:$PATH"
hash -r
command -v ghc | grep -q ghc88-prefix || fail "PATH ghc is $(command -v ghc)"
command -v happy | grep -q happy-1.19.5-prefix || fail "PATH happy is $(command -v happy)"
ver=$("$ROOT/build/ghc88-work/ghc88-prefix/bin/ghc" --numeric-version | tr -d '[:space:]')
[ "$ver" = "8.8.4" ] || fail "boot numeric-version is '$ver'"
hver=$("$ROOT/build/ghc74-tools/happy-1.19.5-prefix/bin/happy" --version | tr -d '\r')
printf '%s\n' "$hver" | grep -q 'Happy Version 1.19.5' || fail "boot happy is '$hver'"

python - "$IN/happy11912-inner.sh" "$ROOT/build/happy11912-inner.sh" << 'PY'
import sys
src, dst = sys.argv[1:]
text = open(src, encoding="utf-8").read()
if text.count("/media/space") != 1:
    sys.exit("expected one /media/space before adapt, found %s" % text.count("/media/space"))
repls = [
    ("ROOT=/media/space/repos/GHC-MicroHs-bootstrap\n", "ROOT=${STAGE:?}\n"),
    ("CPPHS=$ROOT/build/bin/cpphs\n", "CPPHS=/usr/bin/cpphs-mhs\n"),
    # share/doc/.../happy-1.19.12 also exists. -print -quit can count that
    # one-file dir instead of the 13 templates.
    (
        'sharedir=$(find "$PREFIX/share" -type d -name happy-1.19.12 -print -quit)\n',
        'sharedir=$(find "$PREFIX/share" -type d -name happy-1.19.12 -exec test -f \'{}/HappyTemplate\' \';\' -print -quit)\n',
    ),
]
for old, new in repls:
    n = text.count(old)
    if n != 1:
        sys.exit("adapt count %s for %r" % (n, old))
    text = text.replace(old, new, 1)
if "/media/space" in text:
    sys.exit("inner script still mentions /media/space")
if "--prefix=/usr" in text:
    sys.exit("inner script must not configure --prefix=/usr")
if 'PREFIX=$WORK/happy-1.19.12-prefix\n' not in text:
    sys.exit("PREFIX assignment missing")
open(dst, "w", encoding="utf-8").write(text)
PY
chmod 755 "$ROOT/build/happy11912-inner.sh"
bash "$ROOT/build/happy11912-inner.sh"
[ -f "$ROOT/build/happy11912-work/stamps/happy.ok" ] || fail "happy stamp missing"

TREE=$ROOT/build/happy11912-work/src/happy-1.19.12
GHC=$ROOT/build/ghc88-work/ghc88-prefix
[ -x "$TREE/Setup" ] || fail "happy Setup missing"
[ -f "$TREE/data/HappyTemplate" ] || fail "generated HappyTemplate missing"

rm -rf "$ROOT/dest" "$ROOT/cabal-copy"
mkdir -p "$ROOT/dest/bin" "$ROOT/dest/share"
(
	cd "$TREE"
	rm -rf dist
	./Setup configure -v0 --prefix=/usr \
		--with-compiler="$GHC/bin/ghc" --with-hc-pkg="$GHC/bin/ghc-pkg" \
		--ghc-option=-rtsopts
	./Setup build -v0
	./Setup copy -v0 --destdir="$ROOT/cabal-copy"
)

bin=$ROOT/cabal-copy/usr/bin/happy
share=$ROOT/cabal-copy/usr/share/x86_64-linux-ghc-8.8.4/happy-1.19.12
[ -x "$bin" ] || fail "cabal copy produced no usr/bin/happy"
[ -f "$share/HappyTemplate" ] || fail "cabal copy produced no HappyTemplate"
file "$bin" | grep -q ELF || fail "rebuilt happy is not an ELF"
if grep -a -F -q '/media/space' "$bin"; then
	fail "rebuilt happy contains /media/space"
fi
if grep -a -F -q 'happy-1.19.12-prefix' "$bin"; then
	fail "rebuilt happy still points at the work prefix"
fi
grep -a -F -q '/usr/share/x86_64-linux-ghc-8.8.4/happy-1.19.12' "$bin" \
	|| fail "happy datadir was not baked"
nshare=$(find "$share" -maxdepth 1 -type f | wc -l | tr -d '[:space:]')
[ "$nshare" = 13 ] || fail "rebuilt happy share count $nshare"
install -m 755 "$bin" "$ROOT/dest/bin/happy11912.real"
mkdir -p "$ROOT/dest/share/x86_64-linux-ghc-8.8.4"
cp -a "$share" "$ROOT/dest/share/x86_64-linux-ghc-8.8.4/happy-1.19.12"
rm -rf "$ROOT/cabal-copy"

cat > "$ROOT/dest/bin/happy11912" << 'EOF'
#!/bin/bash
set -eu
arg0=$0
if [ ! -x "$arg0" ] || [ "$arg0" = "${arg0#*/}" ]; then
	arg0=$(command -v "$0") || exit 1
fi
here=$(CDPATH= cd -- "$(dirname "$(readlink -f "$arg0")")" && pwd)
exec "$here/happy11912.real" +RTS -K64M -H128M -RTS "$@"
EOF
chmod 755 "$ROOT/dest/bin/happy11912"
[ ! -e "$ROOT/dest/bin/happy" ] || fail "refusing to ship /usr/bin/happy"
[ ! -e "$ROOT/dest/bin/happy.real" ] || fail "refusing to ship happy.real"
printf 'happy11912: staged %s\n' "$ROOT/dest"
