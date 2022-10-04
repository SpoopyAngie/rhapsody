FROM ubuntu:jammy

RUN apt update &&\
    apt install -y --no-install-recommends git curl yt-dlp ffmpeg libopus-dev libsodium-dev &&\
    rm -rf /var/lib/apt/lists/*

WORKDIR /root/

RUN curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh

RUN mv lit /usr/local/bin &&\
    mv luvi /usr/local/bin &&\
    mv luvit /usr/local/bin

RUN git clone https://github.com/SpoopyAngie/rhapsody.git

WORKDIR /root/rhapsody
RUN lit install SinisterRectus/discordia

VOLUME /root/rhapsody/cache

CMD ["luvit", "init.lua"]