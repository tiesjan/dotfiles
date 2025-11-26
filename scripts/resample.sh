#!/usr/bin/env dash

ORIGINAL_FILENAME_PREFIX="ORIGINAL_"
RESAMPLING_FILENAME_PREFIX="RESAMPLING_"

OUTPUT_SAMPLE_FORMAT="s16"
OUTPUT_SAMPLE_RATE=44100


bail () {
    if [ $# -gt 0 ]
    then
        printf "\nError! %s\n" "$@" >&2
    fi

    exit 1
}


warn () {
    printf "Warning! %s\n" "$@" >&2
}


resample_file () {
    if [ $# -ne 5 ]
    then
        bail "Function \`resample_file()\` expected 5 arguments, $# were given."
    fi

    file_path="$1"
    audio_format="$2"
    audio_format_args="$3"
    force_resampling="$4"
    preserve_mtime="$5"

    # Retrieve audio stream information from file
    if ! file_info=$(ffprobe -v quiet -print_format json -show_streams "${file_path}")
    then
        warn "Not a media file: ${file_path}"
        return
    fi

    stream_info=$(printf "%s" "${file_info}" | jq '.streams[] | select(.codec_type == "audio")')
    sample_format=$(printf "%s" "${stream_info}" | jq --raw-output '.sample_fmt')
    sample_rate=$(( $(printf "%s" "${stream_info}" | jq --raw-output '.sample_rate | tonumber') ))

    if [ "${force_resampling}" = false ]
    then
        # Quit early if the output sample format and sample rate match the input file
        if [ "${sample_format}" = "${OUTPUT_SAMPLE_FORMAT}" ] || [ "${sample_rate}" -eq ${OUTPUT_SAMPLE_RATE} ]
        then
            printf "Skipping %s\n" "${file_path}"
            return
        fi
    fi

    printf "Resampling %s...\n" "${file_path}"

    # Resample file
    sample_format="${OUTPUT_SAMPLE_FORMAT}"
    sample_rate="${OUTPUT_SAMPLE_RATE}"
    working_dir="$(dirname "${file_path}")"
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

    original_file_path="${working_dir}/${ORIGINAL_FILENAME_PREFIX}$(basename "${file_path}")"

    # Keep original audio file with prefix in the filename
    mv "${file_path}" "${original_file_path}"

    # Replace original file with resampled audio file
    mv "${output_file_path}" "${file_path}"

    if [ "${preserve_mtime}" = true ]
    then
        # Take over the modification time from the original file
        touch -r "${original_file_path}" "${file_path}"
    fi
}


resample_dir () {
    if [ $# -ne 6 ]
    then
        bail "Function \`resample_file()\` expected 6 arguments, $# were given."
    fi

    dir_path="$1"
    file_extension="$2"
    audio_format="$3"
    audio_format_args="$4"
    force_resampling="$5"
    preserve_mtime="$6"

    for file_path in "${dir_path}"/*."${file_extension}"
    do
        # Skip non-regular files and symlinks
        if [ ! -f "${file_path}" ] || [ -L "${file_path}" ]
        then
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

        resample_file \
            "${file_path}" \
            "${audio_format}" \
            "${audio_format_args}" \
            "${force_resampling}" \
            "${preserve_mtime}"
    done
}


print_usage () {
    printf "Usage: resample [--force | --no-preserve-mtime] <FORMAT> <PATH>\n"
    printf "  <FORMAT> is one of the supported output formats: aiff, flac\n"
    printf "  <PATH> is the path to a directory or a regular file\n"
    printf "  --force will resample regardless of the target sampling format or rate\n"
    printf "  --no-preserve-mtime will not take over the modification time from the original file\n"
}


main () {
    output_format=""
    path=""

    force_resampling=false
    preserve_mtime=true

    positional_argument_count=0
    while [ $# -gt 0 ]
    do
        case "$1" in
            "--force")
                force_resampling=true
                shift
                ;;
            "--no-preserve-mtime")
                preserve_mtime=false
                shift
                ;;
            "--"*)
                print_usage
                bail "Unknown argument: '$1'."
                ;;
            *)
                if [ ${positional_argument_count} -eq 0 ]
                then
                    output_format="$1"
                    positional_argument_count=$((positional_argument_count+1))
                    shift
                elif [ ${positional_argument_count} -eq 1 ]
                then
                    path="$1"
                    positional_argument_count=$((positional_argument_count+1))
                    shift
                else
                    print_usage
                    bail "Too many positional arguments."

                fi
                ;;
        esac
    done

    if [ "${positional_argument_count}" -ne 2 ]
    then
        print_usage
        bail
    fi

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
    if [ -f "${path}" ] && [ ! -L "${path}" ]
    then
        resample_file \
            "${path}" \
            "${audio_format}" \
            "${audio_format_args}" \
            "${force_resampling}" \
            "${preserve_mtime}"

    # Handle directories
    elif [ -d "${path}" ]
    then
        resample_dir \
            "${path}" \
            "${file_extension}" \
            "${audio_format}" \
            "${audio_format_args}" \
            "${force_resampling}" \
            "${preserve_mtime}"

    else
        print_usage
        bail "Given <PATH> is not a directory or a regular file: '${path}'"
    fi
}


main "$@"; exit
