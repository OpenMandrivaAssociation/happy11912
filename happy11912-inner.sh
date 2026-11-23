#!/bin/bash
# happy 1.19.12, built by the in-chain GHC 8.8.4 from the Hackage tarball.
# Grammars and templates are the 1.19.12 tag sources (not in the tarball).
# Templates are cpphs 1.20.9 output and must match the tarball byte for byte.
# Gen 1 is happy 1.19.5 (plain). Gen 2 is this happy with -agc. The gcc-cpp
# template is what 1.19.10 used for the parsers the tarball ships.
set -euo pipefail

ROOT=/media/space/repos/GHC-MicroHs-bootstrap
R=$ROOT/build/ref-ghc-bootstrap
WORK=$ROOT/build/happy11912-work
TREE=$WORK/src/happy-1.19.12
PREFIX=$WORK/happy-1.19.12-prefix
GHC=$ROOT/build/ghc88-work/ghc88-prefix
HAPPY=$ROOT/build/ghc74-tools/happy-1.19.5-prefix
CPPHS=$ROOT/build/bin/cpphs
TAG=$ROOT/build/sources/happy-1.19.12-tag
SRC=$ROOT/build/sources/happy-1.19.12.tar.gz
EXPECT_SHA=fb9a23e41401711a3b288f93cf0a66db9f97da1ce32ec4fffea4b78a0daeb40f
CPP=$R/ghc66/cpp-template.sh
CMP=$R/ghc66/cmp-generated.sh

export TMPDIR=$WORK/tmp
mkdir -p "$TMPDIR" "$WORK/logs" "$WORK/src" "$WORK/stamps"

exec 9>"$WORK/build.lock"
flock -n 9 || { printf 'HAPPY11912_FAILED: another build holds %s\n' "$WORK/build.lock"; exit 1; }

phase() { printf 'HAPPY11912_PHASE %s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
failed=0
fail() { failed=1; printf 'HAPPY11912_FAILED: %s\n' "$*"; exit 1; }
trap 'rc=$?; if [ "$rc" -ne 0 ] && [ "$failed" != 1 ]; then printf "HAPPY11912_FAILED: exit %s\n" "$rc"; fi' EXIT

printf '%s\n' "$$" > "$WORK/bootstrap.pid"
ulimit -s unlimited 2>/dev/null || true
phase "start pid $$"

[ -x "$GHC/bin/ghc" ] || fail "ghc missing"
ver=$("$GHC/bin/ghc" --numeric-version | tr -d '[:space:]')
[ "$ver" = "8.8.4" ] || fail "boot numeric-version is '$ver'"
phase "boot compiler 8.8.4"
[ -x "$HAPPY/bin/happy" ] || fail "happy 1.19.5 missing"
[ -x "$CPPHS" ] || fail "cpphs missing"
cpphs_ver=$("$CPPHS" --version 2>&1 | head -1 | tr -d '\r')
printf '%s\n' "$cpphs_ver" | grep -q '1.20.9' || fail "cpphs is '$cpphs_ver'"
[ -f "$CPP" ] || fail "cpp-template.sh missing"
[ -f "$CMP" ] || fail "cmp-generated.sh missing"
got_sha=$(sha256sum "$SRC" | awk '{print $1}')
[ "$got_sha" = "$EXPECT_SHA" ] || fail "tarball sha256 $got_sha"
for f in src/Parser.ly src/AttrGrammarParser.ly templates/GenericTemplate.hs templates/GLR_Base.hs templates/GLR_Lib.hs; do
	[ -f "$TAG/$f" ] || fail "tag file missing: $f"
done

clean=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v -e '\.ghcup' -e '\.cabal' -e '/ghc66-work/' -e '/ghc610-work/' -e '/ghc612-work/' -e '/ghc74-work/' -e '/ghc74-tools/' -e '/ghc78-work/' -e '/ghc80-work/' -e '/ghc84-work/' -e '/ghc88-work/' -e '/happy11912-work/' | paste -sd: -)
export PATH="$GHC/bin:$HAPPY/bin:$ROOT/build/ghc88-work/bin:$clean"
unset LD_LIBRARY_PATH || true
unset GHC_PACKAGE_PATH || true
hash -r
command -v ghc | grep -q ghc88-prefix || fail "PATH ghc is $(command -v ghc)"
command -v happy | grep -q happy-1.19.5-prefix || fail "PATH happy is $(command -v happy)"
phase "tools on PATH"

phase "unpack"
rm -rf "$TREE" "$PREFIX"
tar -C "$WORK/src" -xzf "$SRC"
[ -f "$TREE/Setup.hs" ] || fail "unpack did not produce Setup.hs"
cd "$TREE"

phase "stage shipped parsers and templates"
mkdir -p shipped/data grammar templates tmpl-gcc
/bin/mv -f src/Parser.hs src/AttrGrammarParser.hs shipped/
/bin/mv -f data/* shipped/data/
/bin/cp -f "$TAG/src/Parser.ly" grammar/Parser.ly
/bin/cp -f "$TAG/src/AttrGrammarParser.ly" grammar/AttrGrammarParser.ly
/bin/cp -f "$TAG/templates/GenericTemplate.hs" templates/GenericTemplate.hs
/bin/cp -f "$TAG/templates/GLR_Base.hs" templates/GLR_Base.hs
/bin/cp -f "$TAG/templates/GLR_Lib.hs" templates/GLR_Lib.hs
# Relative paths: the LINE pragma must name templates/<src>, as the tarball's do.
t() {
	src=$1
	dst=$2
	shift 2
	"$CPPHS" --linepragma "$@" "templates/$src" -O"data/$dst"
}
t GenericTemplate.hs HappyTemplate
t GenericTemplate.hs HappyTemplate-ghc -DHAPPY_GHC
t GenericTemplate.hs HappyTemplate-coerce -DHAPPY_GHC -DHAPPY_COERCE
t GenericTemplate.hs HappyTemplate-arrays -DHAPPY_ARRAY
t GenericTemplate.hs HappyTemplate-arrays-ghc -DHAPPY_ARRAY -DHAPPY_GHC
t GenericTemplate.hs HappyTemplate-arrays-coerce -DHAPPY_ARRAY -DHAPPY_GHC -DHAPPY_COERCE
t GenericTemplate.hs HappyTemplate-arrays-debug -DHAPPY_ARRAY -DHAPPY_DEBUG
t GenericTemplate.hs HappyTemplate-arrays-ghc-debug -DHAPPY_ARRAY -DHAPPY_GHC -DHAPPY_DEBUG
t GenericTemplate.hs HappyTemplate-arrays-coerce-debug -DHAPPY_ARRAY -DHAPPY_GHC -DHAPPY_COERCE -DHAPPY_DEBUG
t GLR_Base.hs GLR_Base
t GLR_Lib.hs GLR_Lib
t GLR_Lib.hs GLR_Lib-ghc -DHAPPY_GHC
t GLR_Lib.hs GLR_Lib-ghc-debug -DHAPPY_GHC -DHAPPY_DEBUG
nshare=$(find data -maxdepth 1 -type f | wc -l | tr -d '[:space:]')
[ "$nshare" = "13" ] || fail "template count $nshare"
for f in data/*; do
	b=$(basename "$f")
	cmp -s "$f" "shipped/data/$b" || fail "template $b differs from the tarball"
done
phase "thirteen templates match the tarball"

phase "Setup"
ghc --make -v0 Setup.hs -o Setup

build() {
	gen=$1
	rm -rf dist "inst-$gen"
	./Setup configure -v0 --prefix="$PWD/inst-$gen" \
		--with-compiler="$GHC/bin/ghc" --with-hc-pkg="$GHC/bin/ghc-pkg" \
		--ghc-option=-rtsopts
	./Setup build -v0
	./Setup install -v0
	/bin/cp -f "inst-$gen/bin/happy" "happy-$gen"
}
regen() {
	gen=$1
	mkdir -p "gen$gen"
	for p in Parser AttrGrammarParser; do
		"./happy-$gen" +RTS -K64M -H128M -RTS -agc "grammar/$p.ly" -o "gen$gen/$p.hs"
	done
}

phase "gen0 with happy 1.19.5"
for p in Parser AttrGrammarParser; do
	happy "grammar/$p.ly" -o "src/$p.hs"
done
phase "build 1"
build 1
regen 1
phase "gcc-cpp template compare"
sh "$CPP" "$GHC/bin/ghc" templates/GenericTemplate.hs tmpl-gcc/HappyTemplate-arrays-coerce \
	-DHAPPY_ARRAY -DHAPPY_GHC -DHAPPY_COERCE
mkdir -p gen1-gcc
for p in Parser AttrGrammarParser; do
	./happy-1 +RTS -K64M -H128M -RTS -agc --template=tmpl-gcc "grammar/$p.ly" -o "gen1-gcc/$p.hs"
	sed 's/^-- parser produced by Happy Version [0-9.]*$/-- parser produced by Happy Version 1.19.12/' \
		"shipped/$p.hs" > "shipped/$p.hs.v"
	sh "$CMP" "gen1-gcc/$p.hs" "shipped/$p.hs.v"
done
phase "shipped parsers match the gcc-cpp template"
/bin/cp -f gen1/Parser.hs gen1/AttrGrammarParser.hs src/
phase "build 2"
build 2
regen 2
cmp gen1/Parser.hs gen2/Parser.hs
cmp gen1/AttrGrammarParser.hs gen2/AttrGrammarParser.hs
phase "fixed point"

phase "install"
rm -rf dist
./Setup configure -v0 --prefix="$PREFIX" \
	--with-compiler="$GHC/bin/ghc" --with-hc-pkg="$GHC/bin/ghc-pkg" \
	--ghc-option=-rtsopts
./Setup build -v0
./Setup install -v0
mkdir -p "$PREFIX/share/generated"
/bin/cp -f gen2/*.hs "$PREFIX/share/generated/"
hver=$("$PREFIX/bin/happy" --version | tr -d '\r')
printf '%s\n' "$hver" | grep -q 'Happy Version 1.19.12' || fail "installed happy '$hver'"
# Cabal 3.0 installs data-files under share/<arch>-ghc-<ver>/happy-1.19.12.
sharedir=$(find "$PREFIX/share" -type d -name happy-1.19.12 -print -quit)
[ -d "$sharedir" ] || fail "no happy-1.19.12 data dir under $PREFIX/share"
nshare=$(find "$sharedir" -maxdepth 1 -type f | wc -l | tr -d '[:space:]')
[ "$nshare" = "13" ] || fail "installed template count $nshare in $sharedir"
cmp <("$PREFIX/bin/happy" -agc grammar/Parser.ly -o /dev/stdout) gen2/Parser.hs
/bin/mv -f "$PREFIX/bin/happy" "$PREFIX/bin/happy.real"
cat > "$PREFIX/bin/happy" <<'EOF'
#!/bin/bash
exec "$(dirname "$0")/happy.real" +RTS -K64M -H128M -RTS "$@"
EOF
chmod +x "$PREFIX/bin/happy"
hver=$("$PREFIX/bin/happy" --version | tr -d '\r')
printf '%s\n' "$hver" | grep -q 'Happy Version 1.19.12' || fail "wrapped happy '$hver'"
hver2=$("$PREFIX/bin/happy" --version | tr -d '\r')
printf '%s\n' "$hver2" | grep -q 'Happy Version 1.19.12' || fail "second wrapped happy '$hver2'"
cmp <("$PREFIX/bin/happy" -agc grammar/Parser.ly -o /dev/stdout) gen2/Parser.hs
printf '%s\n%s\n' "$hver" "$hver2" > "$WORK/logs/happy-version.log"
touch "$WORK/stamps/happy.ok"
printf 'HAPPY11912_DONE installed %s\n' "$PREFIX/bin/happy"
