FROM waggle/plugin-base:0.1.0

RUN apt-get update \
  && apt-get install -y \
  ffmpeg \
  curl \
  inotify-tools \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY configs/_ffserver.conf /app
COPY stream.sh sample.sh /app/

ENTRYPOINT ["/bin/bash", "/app/stream.sh"]
