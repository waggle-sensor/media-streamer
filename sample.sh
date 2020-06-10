#!/bin/bash

help() {
  echo " Take samples from a stream"
  echo " USAGE: sample.sh [OPTIONS] [FFMPEG PARAMS]"
  echo "    [OPTIONS]"
  echo "    -h            print usage"
  echo "    -verbose      print logs"
  echo "    -stream       url of the stream"
  echo "    -period       sampling period in seconds"
  echo "                  0 means an image; > 1 means video or audio"
  echo "    -interval     sampling interval in seconds"
  echo "                  if not specified, 30 is used"
  echo "    -out_dir      path to the output directory"
  echo "                  if not specified, /tmp is used"  
}

unparsed_parameters=()
while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    -h)
    help
    exit 0
    ;;
    -stream)
    input_stream="$2"
    shift
    shift
    ;;
    -out_dir)
    out_dir="$2"
    shift
    shift
    ;;
    -interval)
    interval="$2"
    shift
    shift
    ;;
    -period)
    period="$2"
    shift
    shift
    ;;
    -verbose)
    verbose="true"
    shift
    ;;
    *)
    unparsed_parameters+=("$1")
    shift
    ;;
  esac
done

print() {
  loglevel=$1
  message=$2
  echo "$(date) $loglevel $message"
}

if [ -z $input_stream ]; then
  print "ERROR" "No input stream specified!"
  exit 1
fi

if [ -z ${out_dir} ]; then
  out_dir=/tmp
  print "INFO" "No out_dir specified. Use /tmp"
fi
if [ ! -d $out_dir ]; then
  print "ERROR" "out_dir path must be a directory path"
  exit 1
fi

if [ ! -z "${interval##*[!0-9]*}" ]; then
  :
else
  interval=30
  print "WARNING" "No interval specified or interval is negative value. Use 30 seconds interval."
fi

if [ ! -z "${period##*[!0-9]*}" ]; then
  :
else
  period=0
  print "WARNING" "No period specified. Use no period."
fi

print "INFO" "Probing the input stream..."
stream_type=$(ffprobe \
  -loglevel panic \
  -i $input_stream \
  -show_entries stream=codec_type \
  | grep codec_type \
  | cut -d '=' -f 2)
print "INFO" "type is ${stream_type}"

if [ "${stream_type}x" == "x" ]; then
  print "ERROR" "Cannot identify type of the input stream."
  exit 1
fi

if [ "${stream_type}x" == "videox" ]; then
  if [ $period -eq 0 ]; then
    ffmpeg_params="-vframes 1 -f image2"
    extension="jpg"
  elif [ $period -gt 0 ]; then
    ffmpeg_params="-t ${period}"
    extension="mp4"
  else
    print "ERROR" "period option cannot be negative."
    exit 1
  fi
elif [ "${stream_type}x" == "audiox" ]; then
  ffmpeg_params="-t ${period}"
  extension="mp3"
else
  print "ERROR" "Unknown stream type: ${stream_type}"
  exit 1
fi

print "INFO" "Sampling starts..."
while :;
do
  output_file=${out_dir}/$(date -Iseconds).${extension}
  timeout $((${period}+60)) ffmpeg \
    -loglevel error \
    -i $input_stream \
    ${ffmpeg_params} \
    ${unparsed_parameters[@]} \
    ${output_file}
  return_code=$?
  if [ ${return_code} -ne 0 ]; then
    if [ ! -z ${verbose} ]; then
      print "ERROR" "Could not sample: return code ${return_code}"
    fi
  fi

  if [ ! -z ${verbose} ]; then
    print "INFO" "${output_file}"
    print "INFO" "Next sampling in ${interval} seconds"
  fi
  sleep ${interval}
done
