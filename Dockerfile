FROM ruby:2.5.1-slim-stretch

VOLUME /dev/shm

ENV HOME=/chunithm-recoder
WORKDIR $HOME

RUN apt-get update && apt-get install -y unzip wget busybox-static curl gnupg2 && \
    CHROME_DRIVER_VERSION=`curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE` && \
    wget -N http://chromedriver.storage.googleapis.com/$CHROME_DRIVER_VERSION/chromedriver_linux64.zip -P ~/ && \
    unzip ~/chromedriver_linux64.zip -d ~/ && \
    rm ~/chromedriver_linux64.zip && \
    chown root:root ~/chromedriver && \
    chmod 755 ~/chromedriver && \
    mv ~/chromedriver /usr/bin/chromedriver && \
    sh -c 'wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -' && \
    sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list' && \
    apt-get update && apt-get install -y google-chrome-stable

RUN apt-get install -y build-essential patch ruby-dev zlib1g-dev liblzma-dev

COPY Gemfile $HOME
COPY Gemfile.lock $HOME
RUN bundle install

COPY config $HOME/config
COPY lib $HOME/lib
COPY Rakefile $HOME
COPY unicorn.conf $HOME
COPY config.ru $HOME

RUN mkdir -p $HOME/tmp/pids $HOME/log
RUN mkdir -p /var/spool/cron/crontabs/
ENV TZ=Asia/Tokyo
RUN echo '* 1 * * * cd /chunithm-recoder && bundle exec rake record' > /var/spool/cron/crontabs/root

CMD ["busybox", "crond", "-f"]
