FROM ruby:slim

ENV DEBIAN_FRONTEND=noninteractive

LABEL authors="Amir Pourmand,George Araújo" \
      description="Docker image for al-folio academic template" \
      maintainer="Amir Pourmand"

# 시스템 의존성 + ImageMagick
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        git \
        imagemagick \
        inotify-tools \
        locales \
        nodejs \
        procps \
        python3-pip \
        zlib1g-dev && \
    pip --no-cache-dir install --upgrade --break-system-packages nbconvert && \
    apt-get clean && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/*

# 로케일
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

# 환경변수
ENV EXECJS_RUNTIME=Node \
    JEKYLL_ENV=production \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# 작업 디렉토리
RUN mkdir -p /srv/jekyll
WORKDIR /srv/jekyll

# Gem 설치 (빌드 캐시 활용)
ADD Gemfile.lock /srv/jekyll
ADD Gemfile /srv/jekyll
RUN gem install --no-document jekyll bundler
RUN bundle install --no-cache

# 엔트리포인트 스크립트
COPY bin/entry_point.sh /tmp/entry_point.sh
RUN chmod +x /tmp/entry_point.sh   # 👈 추가

EXPOSE 8080
CMD ["/tmp/entry_point.sh"]