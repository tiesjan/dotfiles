#!/usr/bin/env dash


print_usage () {
    printf "Sanitizes the provided text string.\n"
    printf "\n"
    printf "Usage: sanitize <RULESET> <TEXT>\n"
    printf "  <RULESET> is one of the supported sanitization rulesets: filename\n"
    printf "  <TEXT> is the text string to sanitize\n"
}


sanitize_filename () {
    # Sanitizes the given text string according to safe filename ruleset:
    # - removes illegal characters
    # - replaces double quotes (\x22) with single quotes (\x27)
    # - strips leading spaces and dots
    # - strips trailing spaces and dots
    # - merges consecutive spaces

    printf "%s" "$1" | tr -d ':><|*/?\\[:cntrl:]' \
                     | sed -E -e 's/\x22/\x27/g' \
                              -e 's/^[[:space:]\.]+//' \
                              -e 's/[[:space:]\.]+$//' \
                              -e 's/[[:space:]][[:space:]]+/ /g'
}


main () {
    if [ $# -ne 2 ]
    then
        print_usage
        exit
    fi

    ruleset="$1"
    text="$2"

    case "${ruleset}" in
        "filename")
            sanitize_filename "${text}"
            ;;
        *)
            print_usage
            ;;
    esac
}


main "$@"; exit
