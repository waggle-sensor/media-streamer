#!/bin/bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
server_pid=/var/run/waggle/ffserver.pid
input_pid=/var/run/waggle/ffmpeg.pid

echo "Testing stream.sh."

echo "Configuring the test..."
read -p 'Target device (default: /dev/waggle_cam_right): ' device
device=${device:-/dev/waggle_cam_right}
read -p 'Resolution (default: 1280*960): ' image_size
image_size=${image_size:-1280*960}

echo "Launching stream.sh..."
${script_dir}/stream.sh \
  -verbose \
  -f v4l2 \
  -input_format mjpeg \
  -video_size $image_size \
  -i $device \
  -vcodec copy &
stream_pid=$!

clean_up() {
  if ps -p ${stream_pid} > /dev/null ; then
    kill -9 ${stream_pid}
  fi
  sleep 1
  if [ -e ${server_pid} ] ; then
    if ps -p $(cat ${server_pid}) > /dev/null 2>&1 ; then
      kill -9 $(cat ${server_pid})
    fi
  fi
  if [ -e ${input_pid} ] ; then
    if ps -p $(cat ${input_pid}) > /dev/null 2>&1 ; then
      kill -9 $(cat ${input_pid})
    fi
  fi
}

sigint() {
  echo "test interrupted!"
  clean_up
  sleep 1
  exit 0
}

trap sigint SIGINT SIGTERM

echo "Waiting for stream.sh to be running..."
for i in {30..01}
do
  if [ -e ${server_pid} ] && [ -e ${input_pid} ] ; then
    if ps -p $(cat ${server_pid}) > /dev/null && \
       ps -p $(cat ${input_pid}) > /dev/null ; then
      echo "Running."
      break
    fi
  fi
  echo "still waiting. ${i} seconds left..."
  if [ ${i} -eq 01 ]; then
    echo "Timeout! Test failed."
    clean_up
    exit 1
  fi
  sleep 1
done

kill_and_wait_for_respawn() {
  old_pid=$(cat $1)
  kill -9 ${old_pid}
  sleep 1
  for i in {70..01}
  do
    if ps -p $(cat $1) > /dev/null && \
       [ "$(cat $1)x" != "${old_pid}x" ]; then
      echo "${1} respawned." 
      break
    fi
    echo "still waiting. ${i} seconds left..."
    sleep 1
    if [ ${i} -eq 01 ]; then
      echo "Timeout! Test failed."
      clean_up
      exit 1
    fi
  done
}

# NOTE: May need to sleep longer
# as ffmpeg takes more time to be up
sleep 5

echo "Attemping to kill the ffserver..."
kill_and_wait_for_respawn ${server_pid}

sleep 10
echo "Attemping to kill the input feeder..."
kill_and_wait_for_respawn ${input_pid}

echo "Terminating stream.sh..."
clean_up

echo "Test done"
