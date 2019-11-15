FROM node:10.16.0
ARG codeServerVersion=docker
ARG vscodeVersion
ARG githubToken
# Install VS Code's deps. These are the only two it seems we need.
RUN apt-get update && apt-get install -y \
    git \
	libxkbfile-dev \
	libsecret-1-dev
# Ensure latest yarn.
RUN npm install -g yarn@1.13
WORKDIR /src
RUN git clone https://github.com/cdr/code-server . \
 && git checkout 2.1688-vsc1.39.2
#COPY . .
ENV vscodeVersion=1.39.2 \
    codeServerVersion=2.1688
    
RUN yarn \
	&& MINIFY=true GITHUB_TOKEN="${githubToken}" yarn build "${vscodeVersion}" "${codeServerVersion}" \
	&& yarn binary "${vscodeVersion}" "${codeServerVersion}" \
	&& mv "/src/binaries/code-server${codeServerVersion}-vsc${vscodeVersion}-linux-x86_64" /src/binaries/code-server \
	&& rm -r /src/build \
	&& rm -r /src/source
# We deploy with ubuntu so that devs have a familiar environment.
FROM ubuntu:19.10
RUN apt-get update && apt-get install -y \
	openssl \
	net-tools \
	git \
	git-lfs \
	locales \
	sudo \
	dumb-init \
	vim \
	curl \
	wget \
    nodejs \
    npm \
    golang \
  && rm -rf /var/lib/apt/lists/*
RUN locale-gen en_US.UTF-8
# We cannot use update-locale because docker will not use the env variables
# configured in /etc/default/locale so we need to set it manually.
ENV LC_ALL=en_US.UTF-8 \
	SHELL=/bin/bash
RUN adduser --gecos '' --disabled-password coder && \
	echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd
USER coder
ENV GO111MODULE=on
RUN go get -u -v github.com/ramya-rao-a/go-outline \
 && go get -u -v github.com/acroca/go-symbols \
 && go get -u -v github.com/mdempsky/gocode \
 && go get -u -v github.com/rogpeppe/godef \
 && go get -u -v golang.org/x/tools/cmd/godoc \ 
 && go get -u -v github.com/zmb3/gogetdoc \
 && go get -u -v golang.org/x/lint/golint \
 && go get -u -v github.com/fatih/gomodifytags \
 && go get -u -v golang.org/x/tools/cmd/gorename \
 && go get -u -v sourcegraph.com/sqs/goreturns \
 && go get -u -v golang.org/x/tools/cmd/goimports \
 && go get -u -v github.com/cweill/gotests/... \
 && go get -u -v golang.org/x/tools/cmd/guru \
 && go get -u -v github.com/josharian/impl \
 && go get -u -v github.com/haya14busa/goplay/cmd/goplay \
 && go get -u -v github.com/uudashr/gopkgs/cmd/gopkgs \
 && go get -u -v github.com/davidrjenni/reftools/cmd/fillstruct
# We create first instead of just using WORKDIR as when WORKDIR creates, the
# user is root.
RUN mkdir -p /home/coder/project
WORKDIR /home/coder/project
# This ensures we have a volume mounted even if the user forgot to do bind
# mount. So that they do not lose their data if they delete the container.
VOLUME [ "/home/coder/project" ]
COPY --from=0 /src/binaries/code-server /usr/local/bin/code-server
EXPOSE 8080
ENTRYPOINT ["dumb-init", "code-server", "--host", "0.0.0.0"]
