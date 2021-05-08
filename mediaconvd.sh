#!/bin/bash -eu 
# require apt package 'inotify-tools' 'ffmpeg' 'imagemagick'

export PATH=/bin:/usr/bin

trap "exit 0" 3 # QUITシグナルで停止

declare HOTPATH=/var/lib/samba/shared/media-convert
# inotify の後ろの cat はバッファリング処理のため
# inotifywait のwrite操作でブロックされている間
# ファイルシステムでの操作が入ると、inotify はブロックされている内容を保持しない
# （これは、複数のファイルを一度にコピーした時におきる。）
# このために、一旦 cat でバッファリングさせてシェル側で一行ずつ読み込む
# ダメ。これも出力をキャンセルされちゃう
inotifywait --monitor --event close_write,moved_to "${HOTPATH}" 2> /dev/null | cat | \
    while read -r dirpath event filename ; do
	echo "$dirpath$filename $event"
	case "$event" in 
	    "CLOSE_WRITE,CLOSE")
		if [ -f "${dirpath}${filename}" ] ; then
		    case "$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')" in
			"heic")
			    # srcファイルの所持者の権限で実行する
			    if [ ! -f "${dirpath}${filename%.*}.jpg" ] ; then
				declare msg=$(sudo -n -u $(stat -c '%U' "${dirpath}${filename}") mogrify -format jpg -strip "${dirpath}${filename}")
				if [ ! -z "${msg}" ] ; then
				    echo "${msg}" > "${dirpath}${filename%.*}.log"
				fi
			    else
				echo "${dirpath}${filename%.*}.jpg" is existed, skip the file.
			    fi
			    ;;
			"mov")
			    if [ ! -f "${dirpath}${filename%.*}.mp4" ] ; then
				touch "${dirpath}CONVERT-GO-AHEAD.log"
				declare msg="$(nice ffmpeg -loglevel warning -y -vaapi_device /dev/dri/renderD128 -i "${dirpath}$filename" -vf 'format=nv12,hwupload' -c:v h264_vaapi -b:v 12M  "${dirpath}${filename%.*}-conv.mp4" 2>&1)"
				if [ ! -z "${msg}" ] ; then
				    echo "${msg}" > "${dirpath}${filename%.*}.log"
				fi
				if [ -f "${dirpath}${filename%.*}-conv.mp4" ] ; then
				    mv "${dirpath}${filename%.*}-conv.mp4" "${dirpath}${filename%.*}.mp4"
				fi
				if [ $(id -u) -eq 0 ] ; then
				    if [ -f "${dirpath}${filename%.*}.log" ] ; then
					chown $(stat -c '%U:%G' "${dirpath}${filename}") "${dirpath}${filename%.*}.log"
				    fi
				    if [ -f "${dirpath}${filename%.*}.mp4" ] ; then
					chown $(stat -c '%U:%G' "${dirpath}${filename}") "${dirpath}${filename%.*}.mp4"
				    fi
				else
				    if [ -f "${dirpath}${filename%.*}.log" ] ; then
					sudo chown $(stat -c '%U:%G' "${dirpath}${filename}") "${dirpath}${filename%.*}.log"
				    fi
				    if [ -f "${dirpath}${filename%.*}.mp4" ] ; then
					sudo chown $(stat -c '%U:%G' "${dirpath}${filename}") "${dirpath}${filename%.*}.mp4"
				    fi
				fi
				rm "${dirpath}CONVERT-GO-AHEAD.log"
			    else
				echo "${dirpath}${filename%.*}.mp4" is existed, skip the file.
			    fi
			    ;;
			"mkv")
			    if [ ! -f "${dirpath}${filename%.*}.mp4" ] ; then
				touch "${dirpath}CONVERT-GO-AHEAD.log"
				declare msg="$(nice ffmpeg -loglevel warning -i "${dirpath}$filename" -vcodec copy "${dirpath}${filename%.*}-conv.mp4" 2>&1)"
				if [ ! -z "${msg}" ] ; then
				    echo "${msg}" > "${dirpath}${filename%.*}.log"
				fi
				if [ -f "${dirpath}${filename%.*}-conv.mp4" ] ; then
				    mv "${dirpath}${filename%.*}-conv.mp4" "${dirpath}${filename%.*}.mp4"
				fi
				if [ $(id -u) -eq 0 ] ; then
				    if [ -f "${dirpath}${filename%.*}.log" ] ; then
					chown $(stat -c '%U:%G' "${dirpath}${filename}") "${dirpath}${filename%.*}.log"
				    fi
				    if [ -f "${dirpath}${filename%.*}.mp4" ] ; then
					chown $(stat -c '%U:%G' "${dirpath}${filename}") "${dirpath}${filename%.*}.mp4"
				    fi
				else
				    if [ -f "${dirpath}${filename%.*}.log" ] ; then
					sudo chown $(stat -c '%U:%G' "${dirpath}${filename}") "${dirpath}${filename%.*}.log"
				    fi
				    if [ -f "${dirpath}${filename%.*}.mp4" ] ; then
					sudo chown $(stat -c '%U:%G' "${dirpath}${filename}") "${dirpath}${filename%.*}.mp4"
				    fi
				fi
				rm "${dirpath}CONVERT-GO-AHEAD.log"
			    else
				echo "${dirpath}${filename%.*}.mp4" is existed, skip the file.
			    fi
			    ;;
			"mp4"|"jpg"|"log")
			    ;;
			*)
			    echo "$event" "${dirpath}${filename}" "${filename##*.}"
			    ;;
		    esac
		fi
		;;
	    "MOVED_TO")
		;;
	    *)
		echo "unknown event" "$event" "filename"
		;;
	esac
    done

