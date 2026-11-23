%global debug_package %{nil}
Summary:	Happy 1.19.12 built by GHC 8.8.4
Name:		happy11912
Version:	1.19.12
Release:	1
License:	BSD
Group:		Development/Other
Url:		https://hackage.haskell.org/package/happy
# Complement of distro happy. The binary is happy11912, so no Epoch.
# Grammars and templates are the 1.19.12 tag, not the tarball copies.
ExclusiveArch:	x86_64 znver1
# happy-1.19.12.tar.gz sha256 fb9a23e41401711a3b288f93cf0a66db9f97da1ce32ec4fffea4b78a0daeb40f
Source0:	happy-1.19.12.tar.gz
Source1:	happy-1.19.12-tag.tar.gz
Source2:	happy11912-inner.sh
Source3:	cpp-template.sh
Source4:	cmp-generated.sh
Source5:	happy11912-build.sh
Source6:	%{name}.rpmlintrc

BuildRequires:	ghc88
BuildRequires:	ghc74tools
BuildRequires:	cpphs-mhs
BuildRequires:	gcc
BuildRequires:	make
BuildRequires:	patch
BuildRequires:	perl
BuildRequires:	python
BuildRequires:	diffutils
BuildRequires:	binutils
BuildRequires:	file
BuildRequires:	findutils
BuildRequires:	coreutils
BuildRequires:	util-linux
BuildRequires:	grep
BuildRequires:	sed
BuildRequires:	tar
BuildRequires:	gzip
# The upstream script hashes the tarball with awk.
BuildRequires:	gawk

%description
Happy 1.19.12 compiled by the packaged ghc88 from the Hackage
tarball. Grammars and templates are the 1.19.12 tag sources.
Templates are cpphs 1.20.9 output and must match the tarball.
The previous happy is happy1195. No upstream bindist is used.

Installed as happy11912 so it does not replace the distribution
happy package. The wrapper runs the real binary with a larger RTS stack.

%prep
	set -eu
	cd %{_builddir}
	rm -rf happy11912-root
	mkdir -p happy11912-root/incoming
	cp -a %{SOURCE0} happy11912-root/incoming/happy-1.19.12.tar.gz
	cp -a %{SOURCE1} happy11912-root/incoming/happy-1.19.12-tag.tar.gz
	cp -a %{SOURCE2} happy11912-root/incoming/happy11912-inner.sh
	cp -a %{SOURCE3} happy11912-root/incoming/cpp-template.sh
	cp -a %{SOURCE4} happy11912-root/incoming/cmp-generated.sh
	cp -a %{SOURCE5} happy11912-root/incoming/happy11912-build.sh
	chmod 755 happy11912-root/incoming/happy11912-build.sh
	set +u

%build
	set -eu
	bash "%{_builddir}/happy11912-root/incoming/happy11912-build.sh" "%{_builddir}/happy11912-root" "%{_libdir}"
	set +u

%install
	set -eu
	dest=%{_builddir}/happy11912-root/dest
	mkdir -p %{buildroot}%{_bindir} %{buildroot}%{_datadir}
	cp -a "$dest/bin/." %{buildroot}%{_bindir}/
	cp -a "$dest/share/." %{buildroot}%{_datadir}/
	test -x %{buildroot}%{_bindir}/happy11912
	test -x %{buildroot}%{_bindir}/happy11912.real
	test ! -e %{buildroot}%{_bindir}/happy
	test ! -e %{buildroot}%{_bindir}/happy.real
	file %{buildroot}%{_bindir}/happy11912.real | grep -q ELF
	test -f %{buildroot}%{_datadir}/x86_64-linux-ghc-8.8.4/happy-1.19.12/HappyTemplate
	set +u

%files
%{_bindir}/happy11912
%{_bindir}/happy11912.real
%dir %{_datadir}/x86_64-linux-ghc-8.8.4
%{_datadir}/x86_64-linux-ghc-8.8.4/happy-1.19.12/

%check
	set -eu
	export PATH=%{buildroot}%{_bindir}:$PATH
	hash -r
	b=$(command -v happy11912)
	v=$("$b" --version | tr -d '\r')
	printf '%s\n' "$v" | grep -q 'Happy Version 1.19.12'
	data=%{buildroot}%{_datadir}/x86_64-linux-ghc-8.8.4/happy-1.19.12
	test -f "$data/HappyTemplate"
	# The binary's getDataDir is /usr/share/... . happy_datadir selects the
	# buildroot copy. Grammar is tests/bug002.y from happy 1.19.12.
	rm -rf trivial
	mkdir trivial
	cat > trivial/T.y << 'EOF'
{
module Main where
}
%%name parser
%%token foo { 1 }
%%tokentype { Int }

%%%%

Foo : {- empty -} { () }
Foo : Foo foo     { () }

{
main = return ()
happyError = undefined
}
EOF
	(
		cd trivial
		happy_datadir="$data" "$b" -o T.hs T.y
	)
	test -s trivial/T.hs
	grep -q 'Happy Version 1.19.12' trivial/T.hs
	set +u
