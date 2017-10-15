FROM multiarch/debian-debootstrap:armhf-jessie

RUN apt-get update && apt-get install -y wget curl

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.10
RUN set -x \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu

#    && gosu nobody true

# Install OpenJDK 8 runtime without X11 support
RUN echo "deb http://ftp.debian.org/debian jessie-backports main" | tee /etc/apt/sources.list.d/backports.list \
 && apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 8B48AD6246925553 \
 && apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 7638D0442B90D010 \
 && apt-get update \
 && apt-get -t jessie-backports install -y openjdk-8-jre-headless ca-certificates gnupg openssl tar --no-install-recommends \
 && rm -rf /var/lib/apt/lists/*

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed
ADD docker-java-home.sh /usr/local/bin/docker-java-home

ENV JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk/jre \
    PATH=$PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin \
    ES_JAVA_OPTS='-Xms512m -Xmx512m -Des.path.conf=/usr/share/elasticsearch/config'

# ensure elasticsearch user exists
RUN groupadd -g 911 elasticsearch \
 && useradd -g 911 -u 911 -d /home/elasticsearch -s /bin/bash -m elasticsearch

# https://artifacts.elastic.co/GPG-KEY-elasticsearch
ENV GPG_KEY=46095ACC8548582C1A2699A9D27D666CD88E42B4

WORKDIR /usr/share/elasticsearch

ENV PATH /usr/share/elasticsearch/bin:$PATH

ARG ELASTICSEARCH_VERSION
ENV ELASTICSEARCH_VERSION ${ELASTICSEARCH_VERSION:-5.6.3}

ARG ELASTICSEARCH_TARBALL_SHA1
ENV ELASTICSEARCH_TARBALL_SHA1 ${ELASTICSEARCH_TARBALL_SHA1:-d5e4b61038f2cc3ec7ae5cbecf3406c7ecc7a1c4}

ENV ELASTICSEARCH_TARBALL https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz
ENV ELASTICSEARCH_TARBALL_ASC https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz.asc

RUN set -ex; \
	wget -O elasticsearch.tar.gz "$ELASTICSEARCH_TARBALL"; \
	if [ "$ELASTICSEARCH_TARBALL_SHA1" ]; then \
		echo "$ELASTICSEARCH_TARBALL_SHA1 *elasticsearch.tar.gz" | sha1sum -c -; \
	fi; \
	if [ "$ELASTICSEARCH_TARBALL_ASC" ]; then \
		wget -O elasticsearch.tar.gz.asc "$ELASTICSEARCH_TARBALL_ASC"; \
		export GNUPGHOME="$(mktemp -d)"; \
		gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY"; \
		gpg --batch --verify elasticsearch.tar.gz.asc elasticsearch.tar.gz; \
		rm -rf "$GNUPGHOME" elasticsearch.tar.gz.asc; \
	fi; \
	tar -xf elasticsearch.tar.gz --strip-components=1; \
	rm elasticsearch.tar.gz; \
	mkdir -p ./plugins; \
	for path in \
		./data \
		./logs \
		./config \
		./config/scripts \
	; do \
		mkdir -p "$path"; \
		chown -R elasticsearch:elasticsearch "$path"; \
	done

# we shouldn't need much RAM to test --version (default is 2gb, which gets Jenkins in trouble sometimes)
RUN if [ "${ELASTICSEARCH_VERSION%%.*}" -gt 1 ]; then \
      elasticsearch --version; \
    else \
# elasticsearch 1.x doesn't support --version
# but in 5.x, "-v" is verbose (and "-V" is --version)
      elasticsearch -v; \
    fi

ARG XPACK_VERSION
ENV XPACK_VERSION ${XPACK_VERSION:-5.6.3}

ARG XPACK_TARBALL_SHA1
ENV XPACK_TARBALL_SHA1 ${XPACK_TARBALL_SHA1:-fa9b2b58bf7d373202f586036d4ddf760b6eeba0}

ENV XPACK_TARBALL https://artifacts.elastic.co/downloads/packs/x-pack/x-pack-${XPACK_VERSION}.zip

COPY config/ ./config/

RUN set -ex ; \
    wget -O xpack.tar.gz "$XPACK_TARBALL"; \
    if [ "$XPACK_TARBALL_SHA1" ]; then \
      echo "$XPACK_TARBALL_SHA1 *xpack.tar.gz" | sha1sum -c -; \
    fi; \
    elasticsearch-plugin install --batch file://$PWD/xpack.tar.gz ; \
    rm -f xpack.tar.gz

VOLUME /usr/share/elasticsearch/data

COPY docker-entrypoint.sh /

EXPOSE 9200 9300
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["elasticsearch"]
