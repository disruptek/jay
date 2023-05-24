FROM "alpine"
WORKDIR "/"

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV MAKE_OPTS="-j"

RUN \
	# sys reqs \
	apk add tar gzip unzip zlib openrc util-linux curl-dev && \
	# console and stuff; for completeness \
	ln -s agetty /etc/init.d/agetty.ttyS0 && \
	echo ttyS0 > /etc/securetty && \
	rc-update add agetty.ttyS0 default && \
	rc-update add devfs boot && \
	rc-update add procfs boot && \
	rc-update add sysfs boot && \
	# various deps \
	apk add hiredis hiredis-dev git make linux-headers openssl-dev zlib-dev gcc bsd-compat-headers musl-dev coreutils && \
	# janet \
	git clone https://github.com/janet-lang/janet.git && \
	cd janet && \
	make && \
	make install && \
	make install-jpm-git && \
	cd .. && \
	rm -rf janet

# jay
RUN mkdir /jay
COPY --chmod=644 project.janet /jay
COPY --chmod=644 Makefile /jay
COPY jay /jay/jay

RUN cd /jay && \
	make deps && \
	make install && \
	jpm --local quickbin /jay/jay/server.janet /jay/jpm_tree/bin/jay-server && \
	jpm --local clear-cache && \
	apk del hiredis-dev git make linux-headers openssl-dev zlib-dev gcc bsd-compat-headers musl-dev coreutils && \
	rm -rf /root/.cache

# we'll set the entrypoint but let the user override the arguments
# so that we can avoid replacing the image except under exceptional
# circumstances
# ENV JANET_PATH="/jay/jpm_tree/lib"
ENTRYPOINT ["/jay/jpm_tree/bin/jay-server"]
