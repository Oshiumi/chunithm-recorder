FROM ruby:2.5.1-slim-stretch

ENV HOME=/chunithm-recorder
WORKDIR $HOME

RUN apt-get update && apt-get install -y \
            build-essential \
            patch \
            ruby-dev \
            zlib1g-dev \
            liblzma-dev \
            busybox-static

COPY Gemfile $HOME
COPY Gemfile.lock $HOME
RUN bundle install

COPY config $HOME/config
COPY lib $HOME/lib
COPY bin $HOME/bin

RUN mkdir -p /var/spool/cron/crontabs/
ENV TZ=Asia/Tokyo
RUN echo '10 0 * * * cd /chunithm-recorder && bundle exec ./bin/chunithm record --remote' > /var/spool/cron/crontabs/root

CMD ["busybox", "crond", "-f"]
