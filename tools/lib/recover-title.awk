# Read one decision entry file; print the title recovered from its bold lead paragraph, or
# nothing when prose comes before any bold run.
NR == 1 { next }
!started && /^[[:space:]]*$/ { next }
!started && /^\*\*/ { started = 1 }
!started { exit }
started {
    line = $0
    sub(/^[[:space:]]+/, "", line)
    buf = (buf == "" ? line : buf " " line)
    if (buf ~ /\*\*[[:space:]]*$/ || (length(buf) > 4 && buf ~ /\*\*.*\*\*/)) exit
}
END {
    gsub(/\*\*/, "", buf)
    gsub(/[[:space:]]+/, " ", buf)
    sub(/^ +| +$/, "", buf)
    # The first sentence only.
    sub(/\. [A-Z].*$/, ".", buf)
    sub(/\.$/, "", buf)
    print buf
}
