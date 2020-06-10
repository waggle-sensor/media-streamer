### Media Streamer for Video and Audio

The service utilizes ffserver and ffmpeg to stream a live feed from video/audio devices over http.

#### Usage

To run,

```
# a stream fed from a down-facing camera
device=/dev/waggle_cam_bottom
version=0.1.0
name=cam_bottom_live
$ docker run -d --rm \
  --device ${device} \
  --name ${name} \
  -p 8090:8090 \          # the host also gains access to the stream
  waggle/plugin-media-streaming:${version} \
  -f v4l2 \
  -input_format mjpeg \
  -video_size 640*480 \
  -i ${device} \
  -c:v libx264
```

To get the live feed,

```
# from host use localhost as ${name}
$ ffplay http://${name}:8090/live
# or
$ ffmpeg -i http://${name}:8090/live live.mp4
# or
$ python3
>> import cv2
>> cap = cv2.VideoCapture('http://${name}:8090/live')
>> _, image = cap.read()
```

#### Sampling

While running a media stream container for the live stream, another container using the same Docker image can sample images and audio/video clips from the media stream container.

```
# set a folder in which samples will be saved
storage=/wagglerw/files/image_bottom
name=cam_bottom_live
docker run -d \
  --name image_sampler \
  --restart always \
  --network waggle \   # if the streamer runs on a different network
  -v {storage}:/storage \
  --entrypoint /app/sample.sh \
  waggle/plugin-media-streaming:0.2.0 \
  -verbose \
  -stream http://${name}:8090/live \
  -period 0 \     # if 0 it samples an image, otherwise a video/audio clip
  -interval 600 \ # sampling interval
  -out_dir /storage \
  -vf "transpose=2,transpose=2" # rotate image/video 180 degree if needed
```

#### Developer Notes

- ffmpeg does not support ffserver since 2018. The latest ffmpeg package released since 2019 may not contain ffserver.
