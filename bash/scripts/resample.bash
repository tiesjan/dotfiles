#!/usr/bin/env bash

ORIGINAL_FILENAME_PREFIX="ORIGINAL_"
RESAMPLING_FILENAME_PREFIX="RESAMPLING_"


bail () {
    if [ $# -gt 0 ]; then
        printf "\nError! %s\n" "$@" >&2
    fi

    exit 1
}


warn () {
    printf "Warning! %s\n" "$@" >&2
}


resample_file () {
    if [ $# -ne 3 ]; then
        bail "Function \`resample_file()\` expected 3 arguments, $# were given."
    fi

    file_path="$1"
    working_dir="$(dirname "${file_path}")"

    # Retrieve audio stream information from file
    if ! file_info=$(ffprobe -v quiet -print_format json -show_streams "${file_path}"); then
        warn "Not a media file: ${file_path}"
        return
    fi

    stream_info=$(jq '.streams[] | select(.codec_type == "audio")' <<< "${file_info}")
    sample_format=$(jq --raw-output '.sample_fmt' <<< "${stream_info}")
    sample_rate=$(( $(jq --raw-output '.sample_rate | tonumber' <<< "${stream_info}") ))

    needs_resampling=false

    # Determine sampling format (bit depth)
    if [ "${sample_format}" != "s16" ]; then
        sample_format="s16"

        needs_resampling=true
    fi

    # Determine sample rate
    if [ ${sample_rate} -ne 44100 ]; then
        sample_rate=44100

        needs_resampling=true
    fi

    # Quit early if resampling is not needed
    if [ "${needs_resampling}" = false ]; then
        return
    fi

    printf "Resampling %s...\n" "${file_path}"

    # Resample file
    audio_format="$2"
    audio_format_args="$3"
    output_file_path="${working_dir}/${RESAMPLING_FILENAME_PREFIX}$(basename "${file_path}")"
    ffmpeg \
        -v quiet \
        -i "${file_path}" \
        -f "${audio_format}" \
        ${audio_format_args:+${audio_format_args}} \
        -sample_fmt "${sample_format}" \
        -ar "${sample_rate}" \
        -codec:v copy \
        "${output_file_path}"

    # Keep original audio file with prefix in the filename
    mv "${file_path}" "${working_dir}/${ORIGINAL_FILENAME_PREFIX}$(basename "${file_path}")"

    # Replace original file with resampled audio file
    mv "${output_file_path}" "${file_path}"
}


resample_dir () {
    if [ $# -ne 4 ]; then
        bail "Function \`resample_file()\` expected 4 arguments, $# were given."
    fi

    dir_path="$1"
    file_extension="$2"
    audio_format="$3"
    audio_format_args="$4"

    for file_path in "${dir_path}"/*."${file_extension}"; do
        # Skip non-regular files and symlinks
        if [ ! -f "${file_path}" ] || [ -L "${file_path}" ]; then
            continue
        fi

        # Skip files that have the filename prefixes
        case "$(basename "${file_path}")" in
            ${ORIGINAL_FILENAME_PREFIX}*)
                continue
                ;;
            ${RESAMPLING_FILENAME_PREFIX}*)
                continue
                ;;
        esac

        resample_file "${file_path}" "${audio_format}" "${audio_format_args}"
    done
}


print_usage () {
    printf "Usage: resample <FORMAT> <PATH>\n"
    printf "  <FORMAT> is one of the supported output formats: aiff, flac\n"
    printf "  <PATH> is the path to a directory or a regular file\n"
}


main () {
    if [ $# -ne 2 ]; then
        print_usage
        bail
    fi

    output_format="$1"
    path="$2"

    # Validate audio format
    case "${output_format}" in
        "aiff")
            audio_format="${output_format}"
            audio_format_args="-write_id3v2 1"
            file_extension="${output_format}"
            ;;

        "flac")
            audio_format="${output_format}"
            audio_format_args="-compression_level 12"
            file_extension="${output_format}"
            ;;

        *)
            print_usage
            bail "Given <FORMAT> is not a valid format: '${output_format}'"
            ;;
    esac

    # Handle regular, non-symlink files
    if [ -f "${path}" ] && [ ! -L "${path}" ]; then
        resample_file "${path}" "${audio_format}" "${audio_format_args}"

    # Handle directories
    elif [ -d "${path}" ]; then
        resample_dir "${path}" "${file_extension}" "${audio_format}" "${audio_format_args}"

    else
        print_usage
        bail "Given <PATH> is not a directory or a regular file: '${path}'"
    fi
}


main "$@"; exit
