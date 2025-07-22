# sourced to find alternate names for things

source ./configure

if [ -z "$(command -v "$CROSS_COMPILE$CC")" ]
then
  echo "No $CROSS_COMPILE$CC found" >&2
  exit 1
fi

if [ -z "$SED" ]
then
  [ ! -z "$(command -v gsed 2>/dev/null)" ] && SED=gsed || SED=sed
fi

# Tell linker to do dead code elimination at function level
if [ "$(uname)" == "Darwin" ]
then
  CFLAGS+=" -Wno-deprecated-declarations"
  : ${LDOPTIMIZE:=-Wl,-dead_strip} ${STRIP:=strip}
else
  : ${LDOPTIMIZE:=-Wl,--gc-sections -Wl,--as-needed} ${STRIP:=strip -s -R .note* -R .comment}
fi

# Disable pointless warnings only clang produces
[ -n "$("$CROSS_COMPILE$CC" --version | grep -w clang)" ] &&
  CFLAGS+=" -Wno-string-plus-int -Wno-invalid-source-encoding" ||
# And ones only gcc produces
  CFLAGS+=" -Wno-restrict -Wno-format-overflow"

# Address Sanitizer
if [ -n "$ASAN" ]; then
  # Turn ASan on and disable most optimization to get more readable backtraces.
  # (Technically ASAN is just "-fsanitize=address" and the rest is optional.)
  export CFLAGS="$CFLAGS -fsanitize=address -O1 -g -fno-omit-frame-pointer -fno-optimize-sibling-calls"

  # If the compiler is GCC, statically link the ASan runtime to avoid dynamic linking issues
  if [[ "$CC" == "gcc" ]]; then
    export CFLAGS="$CFLAGS -static-libasan"
  fi
  
  export NOSTRIP=1
  # Ignore leaks on exit. TODO
  export ASAN_OPTIONS="detect_leaks=0"
  # only do this once
  unset ASAN
fi

# Probe number of available processors, and add one.
: ${CPUS:=$(($(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null)+1))}

# If the build is using gnu tools, make them behave less randomly.
export LANG=c
export LC_ALL=C

# Respond to V= by echoing command lines as well as running them
do_loudly() {
  { [ -n "$V" ] && echo "$@" || echo -n "$DOTPROG" ; } >&2
  "$@"
}

# Run a C file from scripts/*.c using $HOSTCC as necessary
brun() {
  [ ! -e "$UNSTRIPPED"/$1 -o "$UNSTRIPPED"/$1 -ot scripts/$1.c ] &&
    { mkdir -p "$UNSTRIPPED" &&
      do_loudly $HOSTCC scripts/$1.c -o "$UNSTRIPPED"/$1 || exit 1; }
  do_loudly "$UNSTRIPPED"/$1 "${@:2}"
}

