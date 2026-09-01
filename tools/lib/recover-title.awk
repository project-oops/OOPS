# Read one entry file; print the title recovered from its bold lead paragraph, or nothing.
# Only the first bold run, and only before any prose - a bold phrase in the middle of an
# argument is emphasis, not a title.
NR == 1 { next }
!started && /^[[:space:]]*$/ { next }
!started && /^\*\*/ { started = 1 }
!started { exit }                      # prose came first: there is no lead to recover
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
    # One sentence. A lead often runs to two - the second is the consequence, and a title
    # carrying it is a paragraph in the index's title column.
    sub(/\. [A-Z].*$/, ".", buf)
    sub(/\.$/, "", buf)
    print buf
}
