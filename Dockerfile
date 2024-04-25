FROM arm64v8/python:3.11.9 AS compile-image

SHELL ["/bin/bash", "-c"]

# Set up virtualenv
ENV VIRTUAL_ENV=/home/mediacms.io
ENV PATH="$VIRTUAL_ENV/bin:$VIRTUAL_ENV/bento4/cmakebuild:$VIRTUAL_ENV/bento4/Source/Python/wrappers:$PATH"
ENV PIP_NO_CACHE_DIR=1

RUN mkdir -p /home/mediacms.io/mediacms/{logs} && cd /home/mediacms.io && python3 -m venv $VIRTUAL_ENV

# Install dependencies:
COPY requirements.txt .

RUN pip install -r requirements.txt

COPY . /home/mediacms.io/mediacms
WORKDIR /home/mediacms.io/mediacms

RUN wget -q https://drmo.eu.org/hub/bento4.zip && \
    unzip bento4.zip -d .. && \
    rm bento4.zip

############ RUNTIME IMAGE ############
FROM arm64v8/python:3.11.9 as runtime-image

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# See: https://github.com/celery/celery/issues/6285#issuecomment-715316219
ENV CELERY_APP='cms'

# Use these to toggle which processes supervisord should run
ENV ENABLE_UWSGI='yes'
ENV ENABLE_NGINX='yes'
ENV ENABLE_CELERY_BEAT='yes'
ENV ENABLE_CELERY_SHORT='yes'
ENV ENABLE_CELERY_LONG='yes'
ENV ENABLE_MIGRATIONS='yes'

# Set up virtualenv
ENV VIRTUAL_ENV=/home/mediacms.io
ENV PATH="$VIRTUAL_ENV/bin:$VIRTUAL_ENV/bento4/cmakebuild:$VIRTUAL_ENV/bento4/Source/Python/wrappers:$PATH"

COPY --chown=www-data:www-data --from=compile-image /home/mediacms.io /home/mediacms.io

RUN apt-get update -y && apt-get -y upgrade && apt-get install --no-install-recommends \
    supervisor nginx imagemagick procps wget xz-utils -y && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get purge --auto-remove && \
    apt-get clean

RUN wget -q https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz && \
    mkdir -p ffmpeg-tmp && \
    tar -xf ffmpeg-release-arm64-static.tar.xz --strip-components 1 -C ffmpeg-tmp && \
    cp -v ffmpeg-tmp/ffmpeg ffmpeg-tmp/ffprobe ffmpeg-tmp/qt-faststart /usr/local/bin && \
    rm -rf ffmpeg-tmp ffmpeg-release-arm64-static.tar.xz

WORKDIR /home/mediacms.io/mediacms

EXPOSE 9000 80

RUN chmod +x ./deploy/docker/entrypoint.sh

ENTRYPOINT ["./deploy/docker/entrypoint.sh"]

CMD ["./deploy/docker/start.sh"]
