FROM openjdk:11-jre-slim

# ensure elasticsearch user exists
RUN addgroup --system elasticsearch && adduser --system --ingroup elasticsearch elasticsearch

# https://artifacts.elastic.co/GPG-KEY-elasticsearch
ENV GPG_KEY 46095ACC8548582C1A2699A9D27D666CD88E42B4

WORKDIR /usr/share/elasticsearch
ENV PATH /usr/share/elasticsearch/bin:$PATH

ENV ELASTICSEARCH_VERSION 7.4.2
ENV ELASTICSEARCH_TARBALL="https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.4.2-linux-x86_64.tar.gz" \
	ELASTICSEARCH_TARBALL_ASC="https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.4.2-linux-x86_64.tar.gz.asc" \
	ELASTICSEARCH_TARBALL_SHA512="64cc3e77f4271a5477c8c979fa48728d96890cad68b0daac6566f4dda25b4d4a80784eaafeaa874a6b434c034fcacb8a5751fdb445919191bae4aa4958c793b7"

RUN apt-get update && apt-get install -y --no-install-recommends gosu
RUN apt-get install -y --no-install-recommends wget
RUN wget -O elasticsearch.tar.gz "$ELASTICSEARCH_TARBALL"
RUN apt-get install -y --no-install-recommends gpg dirmngr gpg-agent

RUN set -ex; \
	if [ "$ELASTICSEARCH_TARBALL_SHA512" ]; then \
		echo "$ELASTICSEARCH_TARBALL_SHA512 *elasticsearch.tar.gz" | sha512sum -c -; \
	fi; \
	\
	if [ "$ELASTICSEARCH_TARBALL_ASC" ]; then \
		wget -O elasticsearch.tar.gz.asc "$ELASTICSEARCH_TARBALL_ASC"; \
		export GNUPGHOME="$(mktemp -d)"; \
		gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$GPG_KEY" || \
		gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$GPG_KEY" || \
		gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$GPG_KEY" ; \
		gpg --batch --verify elasticsearch.tar.gz.asc elasticsearch.tar.gz; \
		rm -rf "$GNUPGHOME" elasticsearch.tar.gz.asc; \
	fi; \
	\
	tar -xf elasticsearch.tar.gz --strip-components=1; \
	rm elasticsearch.tar.gz; \
	\
	apt-get purge -y gpg dirmngr gpg-agent wget; \
	apt-get clean; \
	\
	mkdir -p ./plugins; \
	for path in \
		./data \
		./logs \
		./config \
		./config/scripts \
	; do \
		mkdir -p "$path"; \
		chown -R elasticsearch:elasticsearch "$path"; \
	done; \
  export ES_TMPDIR="$(mktemp -d -t elasticsearch.XXXXXXXX)"; \
  elasticsearch --version; \
  rm -rf "$ES_TMPDIR"

COPY config ./config

VOLUME /usr/share/elasticsearch/data

COPY docker-entrypoint.sh /

EXPOSE 9200 9300
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["elasticsearch"]
