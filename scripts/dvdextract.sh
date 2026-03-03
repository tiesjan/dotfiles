#!/usr/bin/env dash


MODE_EXTRACT_SEGMENTS="extract_segments"
MODE_LIST_KEY_FRAMES="list_key_frames"


bail () {
    if [ $# -gt 0 ]
    then
        printf "Error! %s\n" "$@" >&2
    fi

    exit 1
}


confirm () {
    if [ $# -ne 2 ]
    then
        bail "Function \`confirm()\` expected 2 arguments, $# were given."
    fi

    message="$1"
    default="$2"

    case "${default}" in
        0 ) allowed_choices="[Y/n]" ;;
        1 ) allowed_choices="[y/N]" ;;
        * ) bail "Default value for function \`confirm()\` should be \`0\` or \`1\`."
    esac

    read -r -p "${message} ${allowed_choices} " choice

    case $choice in
        [Yy]*) return 0 ;;
        [Nn]*) return 1 ;;
        *) return "${default}" ;;
    esac
}


load_config () {
    if [ -z "${DVDDB_DIR}" ]
    then
        DVDDB_DIR="${HOME}/.dvddb/"
    fi

    if [ -z "${DVDEXTRACT_TMP_DIR}" ]
    then
        DVDEXTRACT_TMP_DIR="/tmp/"
    fi
}


get_dvd_feature_info() {
    # Retrieves info on the DVD feature, assumed to be the longest track on the DVD

    if [ $# -ne 1 ]
    then
        bail "Function \`get_dvd_feature_info()\` expected 1 argument, $# were given."
    fi

    dvd_info="$1"

    dvd_feature_track_id=$(printf "%s" "${dvd_info}" | jq '.longest_track')
    dvd_feature_info=$(
        printf "%s" "${dvd_info}" |
        jq --argjson track_id "${dvd_feature_track_id}" \
            '.track | sort_by(.ix) | map(select(.ix == $track_id)) | first'
    )

    printf "%s" "${dvd_feature_info}"
}


get_ffmpeg_target() {
    # Constructs the ffmpeg target for a VTS set to extract DVD-Video from

    if [ $# -ne 2 ]
    then
        bail "Function \`get_ffmpeg_target()\` expected 2 arguments, $# were given."
    fi

    target_dir="$1"
    feature_vts_id="$2"

    # DVD-Video always starts at `VTS_XX_1.VOB` (part 1)
    vob_part=1
    while
        vob_file="${target_dir}/VTS_$(printf "%02d" "${feature_vts_id}")_${vob_part}.VOB"
        [ -f "${vob_file}" ]
    do

        if [ "${vob_part}" -eq 1 ]
        then
            ffmpeg_target="concat:${vob_file}"
        else
            ffmpeg_target="${ffmpeg_target}|${vob_file}"
        fi

        vob_part=$((vob_part + 1))
    done

    printf "%s" "${ffmpeg_target}"
}


get_key_frames() {
    # Retrieves the key frames as a JSON array for the specified VTS

    if [ $# -ne 2 ]
    then
        bail "Function \`get_key_frames()\` expected 2 arguments, $# were given."
    fi

    target_dir="$1"
    feature_vts_id="$2"

    ffmpeg_target=$(get_ffmpeg_target "${target_dir}" "${feature_vts_id}")

    key_frames=$(
        ffprobe -loglevel error \
             -select_streams v:0 -skip_frame nokey -show_entries frame=pts_time -output_format json \
             "${ffmpeg_target}" |
        jq '[0] + [.frames[].pts_time | tonumber | . * 1000 | round] | sort'
    )

    printf "%s" "${key_frames}"
}


generate_dvddb_entry() {
    # Generates DVDDB entry based on the provided DVD-Video directory

    if [ $# -ne 3 ]
    then
        bail "Function \`generate_dvddb_entry()\` expected 3 arguments, $# were given."
    fi

    dvd_disc_id="$1"
    dvd_info="$2"
    dvd_dir="$3"

    dvddb_entry=""

    # Write disc info
    dvddb_entry="$(printf "DVD_DISC_ID=%s" "${dvd_disc_id}")\n"

    disc_title=$(
        printf "%s" "${dvd_info}" |
        jq --raw-output 'if .title != "unknown" then .title else "" end'
    )
    dvddb_entry="${dvddb_entry}$(printf "DISC_TITLE=%s" "${disc_title}")\n"

    # Write track info based on DVD feature
    dvd_feature_info=$(get_dvd_feature_info "${dvd_info}")

    feature_vts_id=$(printf "%s" "${dvd_feature_info}" | jq '.vts')
    key_frames=$(get_key_frames "${dvd_dir}" "${feature_vts_id}")

    chapters=$(
        printf "%s" "${dvd_feature_info}" |
        jq '
            # Grab all chapters
            .chapter |

            # Ensure they are sorted by index
            sort_by(.ix) |

            # Convert `length` field from seconds to milliseconds
            [foreach .[] as $ch (null; $ch.length * 1000 | round; $ch + {"length": .})]
        '
    )

    chapters=$(
        printf "%s" "${chapters}" |
        jq --argjson key_frames "${key_frames}" '
            # Calculate start times for each chapter based on the length of the previous chapter
            [{"ix": 1, "start": {"dvd": 0}}] +
            [foreach .[] as $item (0; . + $item.length; {"ix": $item.ix + 1, "start": {"dvd": .}})][:-1]
                as $start_timestamps | . + $start_timestamps | group_by(.ix) | map(add) |

            # Add start times quantized to closest preceding key frames
            [foreach .[] as $ch (
                null;
                $key_frames | map(select(. <= $ch.start.dvd)) | last;
                $ch * {"start": {"quantized": .}}
            )]
        '
    )

    chapter_index=0
    last_chapter_index=$(printf "%s" "${chapters}" | jq 'length - 1')
    while [ "${chapter_index}" -le "${last_chapter_index}" ]
    do
        this_chapter_start=$(
            printf "%s" "${chapters}" |
            jq --argjson index "${chapter_index}" '.[$index].start.dvd'
        )
        this_chapter_quantized_start=$(
            printf "%s" "${chapters}" |
            jq --argjson index "${chapter_index}" '.[$index].start.quantized'
        )

        this_chapter_length=$(
            printf "%s" "${chapters}" |
            jq --argjson index "${chapter_index}" '.[$index].length'
        )
        this_chapter_adjusted_length=$((
            this_chapter_length + (this_chapter_start - this_chapter_quantized_start)
        ))

        if [ "${chapter_index}" -lt "${last_chapter_index}" ]
        then
            next_chapter_quantized_start=$(
                printf "%s" "${chapters}" |
                jq --argjson index $((chapter_index + 1)) '.[$index].start.quantized'
            )

            next_chapter_start_recalculated=$((
                this_chapter_quantized_start + this_chapter_adjusted_length
            ))

            if [ "${next_chapter_start_recalculated}" -gt "${next_chapter_quantized_start}" ]
            then
                this_chapter_adjusted_length=$((
                    next_chapter_quantized_start - this_chapter_quantized_start
                ))
            fi
        fi

        start_sec=$(jq --null-input --argjson start "${this_chapter_quantized_start}" '$start / 1000')
        length_sec=$(jq --null-input --argjson length "${this_chapter_adjusted_length}" '$length / 1000')
        track_index=$((chapter_index + 1))

        dvddb_entry="${dvddb_entry}\n"
        dvddb_entry="${dvddb_entry}$(
            printf "TRACK%02d_SEGMENT=%02d|%.3f|%.3f" \
                "${track_index}" "${feature_vts_id}" "${start_sec}" "${length_sec}"
        )\n"
        dvddb_entry="${dvddb_entry}$(printf "TRACK%02d_ARTIST=" "${track_index}")\n"
        dvddb_entry="${dvddb_entry}$(printf "TRACK%02d_TITLE=" "${track_index}")\n"
        dvddb_entry="${dvddb_entry}$(printf "TRACK%02d_SOURCE=" "${track_index}")\n"

        chapter_index=$((chapter_index + 1))
    done

    printf "%s" "${dvddb_entry}"
}


read_dvddb_entry () {
    # Read an existing DVDDB entry from the provided file path

    if [ $# -ne 1 ]
    then
        bail "Function \`read_dvddb_entry()\` expected 1 argument, $# were given."
    fi

    dvddb_entry_path="$1"

    dvddb_entry=""
    # Read file using `IFS=` to preserve surrounding whitespace and
    # `|| [ ... ]` to include last line even if it does not end with a newline
    while IFS= read -r line || [ "${line}" ]
    do
        dvddb_entry="${dvddb_entry}${line}\n"
    done < "${dvddb_entry_path}"

    # Print using `%b` to expand backslash escaped characters like `\n`
    printf "%b" "${dvddb_entry}"
}


extract_segments () {
    # Takes a DVDDB entry and extracts segments from the DVD directory into the output directory

    if [ $# -ne 4 ]
    then
        bail "Function \`extract_segments()\` expected 4 arguments, $# were given."
    fi

    dvddb_entry="$1"
    disc_title="$2"
    dvd_dir="$3"
    output_dir="$4"

    track_index=1
    while
        track_index_formatted="$(printf "%02d" "${track_index}")"
        printf "%b" "${dvddb_entry}" | grep --quiet "TRACK${track_index_formatted}_SEGMENT="
    do
        segment_line=$(printf "%b" "${dvddb_entry}" | grep "TRACK${track_index_formatted}_SEGMENT=")
        segment="${segment_line#*=}"
        segment_vts_id=$(printf "%s" "${segment}" | cut -d '|' -f 1)
        segment_start=$(printf "%s" "${segment}" | cut -d '|' -f 2)
        segment_length=$(printf "%s" "${segment}" | cut -d '|' -f 3)

        artist_line=$(printf "%b" "${dvddb_entry}" | grep "TRACK${track_index_formatted}_ARTIST=")
        artist="${artist_line#*=}"

        title_line=$(printf "%b" "${dvddb_entry}" | grep "TRACK${track_index_formatted}_TITLE=")
        title="${title_line#*=}"

        source_line=$(printf "%b" "${dvddb_entry}" | grep "TRACK${track_index_formatted}_SOURCE=")
        source="${source_line#*=}"

        output_filename=$(printf "%s. %s - %s.avi" "${track_index_formatted}" "${artist}" "${title}")
        sanitized_output_filename=$(sanitize "filename" "${output_filename}")

        printf "Extracting %s...\n" "${sanitized_output_filename}"

        ffmpeg_target=$(get_ffmpeg_target "${dvd_dir}" "${segment_vts_id}")
        ffmpeg \
            -v quiet \
            -fflags +genpts \
            -i "${ffmpeg_target}" \
            -ss "${segment_start}" -t "${segment_length}" \
            -codec:v copy \
            -codec:a pcm_s16le -ac 2 -ar 44100 \
            -metadata IART="${artist}" -metadata INAM="${title}" \
            -metadata IPRD="${disc_title}" -metadata ISRC="${source}" \
            "${output_dir}/${sanitized_output_filename}"

        track_index=$((track_index + 1))
    done
}


print_dvddb_entry () {
    if [ $# -ne 1 ]
    then
        bail "Function \`print_dvd_db_entry()\` expected 1 argument, $# were given."
    fi

    dvddb_entry="$1"

    disc_title_line=$(printf "%b" "${dvddb_entry}" | grep "DISC_TITLE=")
    # Strip everything up to and including the first equals sign to remove the `DISC_TITLE` prefix
    disc_title="${disc_title_line#*=}"
    if [ -z "${disc_title}" ]
    then
        disc_title="(No Title)"
    fi
    printf -- "----- %s -----\n" "${disc_title}"

    track_index=1
    while
        track_index_formatted="$(printf "%02d" "${track_index}")"
        printf "%b" "${dvddb_entry}" | grep --quiet "TRACK${track_index_formatted}_SEGMENT="
    do
        artist_line=$(printf "%b" "${dvddb_entry}" | grep "TRACK${track_index_formatted}_ARTIST=")
        artist="${artist_line#*=}"
        if [ -z "${artist}" ]
        then
            artist="(Unknown Artist)"
        fi

        title_line=$(printf "%b" "${dvddb_entry}" | grep "TRACK${track_index_formatted}_TITLE=")
        title="${title_line#*=}"
        if [ -z "${title}" ]
        then
            title="(No Title)"
        fi

        printf "  %s. %s - %s\n" "${track_index_formatted}" "${artist}" "${title}"

        track_index=$((track_index + 1))
    done
}


print_usage () {
    printf "Extract segments from a DVD-Video.\n"
    printf "\n"
    printf "Usage: dvdextract [--list-key-frames] <DIR>\n"
    printf "  --list-key-frames will print all the keyframes of the DVD feature and quit\n"
    printf "  <DIR> is the path to a directory containing a full DVD-Video backup\n"
    printf "\n"
    printf "It is recommended to mirror an entire dvd using dvdbackup to the hard drive,\n"
    printf "then run dvdextract against the output directory.\n"
}


main() {
    load_config

    mode="${MODE_EXTRACT_SEGMENTS}"

    while [ $# -gt 0 ]
    do
        case "$1" in
            "--list-key-frames")
                mode="${MODE_LIST_KEY_FRAMES}"
                shift
                ;;
            "--"*)
                print_usage
                bail "Unknown argument: '$1'."
                ;;
            *)
                break
                ;;
        esac
    done

    # A single target directory has not been given when there is not exactly one arguments left
    if [ "$#" -ne 1 ]
    then
        print_usage
        bail
    fi

    dvd_dir="$1"
    if [ ! -d "${dvd_dir}" ]
    then
        bail "Path is not a directory: '${dvd_dir}'"
    fi

    # If a `VIDEO_TS` subdirectory is found inside the target directory, use that instead
    dvd_subdir="${dvd_dir}/VIDEO_TS"
    if [ -d "${dvd_subdir}" ]
    then
        dvd_dir="${dvd_subdir}"
    fi

    if ! dvd_info=$(lsdvd -Oj -x "${dvd_dir}")
    then
        bail "Failed to discover DVD-Video format in directory '${dvd_dir}':\n${dvd_info}"
    fi

    if [ "${mode}" = "${MODE_LIST_KEY_FRAMES}" ]
    then
        dvd_feature_info=$(get_dvd_feature_info "${dvd_info}")

        feature_vts_id=$(printf "%s" "${dvd_feature_info}" | jq '.vts')
        key_frames_list=$(get_key_frames "${dvd_dir}" "${feature_vts_id}" | jq '.[] / 1000')

        formatted_key_frames_list=$(
            printf %s "${key_frames_list}" | while read -r timestamp
            do
                printf "%.3f\n" "${timestamp}"
            done
        )

        printf "%s" "${formatted_key_frames_list}" | less

        exit
    fi

    if [ -z "${VISUAL}" ]
    then
        bail "Please set environment variable \$VISUAL to your favourite editor."
    fi

    dvd_disc_id=$(printf "%s" "${dvd_info}" | jq --raw-output '.dvddiscid')

    cached_dvddb_entry_path="${DVDDB_DIR}/${dvd_disc_id}"
    if [ -f "${cached_dvddb_entry_path}" ]
    then
        printf "Found a cached DVDDB entry for DVD Disc ID '%s'.\n" "${dvd_disc_id}"

        dvddb_entry=$(read_dvddb_entry "${cached_dvddb_entry_path}")
        print_dvddb_entry "${dvddb_entry}"

        confirm_default=1
    else
        printf "Generating DVDDB entry for '%s'...\n" "${dvd_disc_id}"

        dvddb_entry="$(generate_dvddb_entry "${dvd_disc_id}" "${dvd_info}" "${dvd_dir}")"

        confirm_default=0
    fi

    # Set up working directory with DVDDB entry
    working_dir="${DVDEXTRACT_TMP_DIR}/dvdextract.${dvd_disc_id}"
    mkdir -p "${working_dir}"
    temp_dvddb_entry_path="${working_dir}/dvddb_entry"
    printf "%b" "${dvddb_entry}" > "${temp_dvddb_entry_path}"

    if confirm "Do you want to edit the DVDDB entry?" "${confirm_default}"
    then
        $VISUAL "${temp_dvddb_entry_path}"
        dvddb_entry=$(read_dvddb_entry "${temp_dvddb_entry_path}")
    fi

    # Store DVDDB entry in cache
    mkdir -p "${DVDDB_DIR}"
    cp "${temp_dvddb_entry_path}" "${cached_dvddb_entry_path}"

    # Get disc title from DVDDB entry
    disc_title_line=$(printf "%b" "${dvddb_entry}" | grep "DISC_TITLE=")
    disc_title="${disc_title_line#*=}"

    # Create output directory based on disc title
    output_dir=$(sanitize "filename" "${disc_title}")
    if [ -z "${output_dir}" ]
    then
        output_dir="${dvd_disc_id}"
    fi
    mkdir -p "${output_dir}"

    # Extract segments from DVD
    extract_segments "${dvddb_entry}" "${disc_title}" "${dvd_dir}" "${output_dir}"

    # Clean up working directory
    rm -rf "${working_dir}"
}


main "$@"; exit
