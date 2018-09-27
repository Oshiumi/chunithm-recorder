FROM gcr.io/google_appengine/ruby
ARG REQUESTED_RUBY_VERSION="2.5.1"

VOLUME /dev/shm

RUN if test -n "$REQUESTED_RUBY_VERSION" -a \
        ! -x /rbenv/versions/$REQUESTED_RUBY_VERSION/bin/ruby; then \
      (apt-get update -y \
        && apt-get install -y -q gcp-ruby-$REQUESTED_RUBY_VERSION) \
      || (cd /rbenv/plugins/ruby-build \
        && git pull \
        && rbenv install -s $REQUESTED_RUBY_VERSION) \
      && rbenv global $REQUESTED_RUBY_VERSION \
      && gem install -q --no-rdoc --no-ri bundler --version $BUNDLER_VERSION \
      && apt-get clean \
      && rm -f /var/lib/apt/lists/*_*; \
    fi
ENV RBENV_VERSION=${REQUESTED_RUBY_VERSION:-$RBENV_VERSION}

ENV HOME=/chunithm-recoder
WORKDIR $HOME

RUN apt-get update && apt-get install -y unzip wget && \
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

COPY schema.json $HOME
COPY ./lib $HOME/lib
COPY unicorn.conf $HOME
COPY config.ru $HOME
COPY .env $HOME

RUN mkdir -p $HOME/tmp/pids $HOME/log
CMD ["bundle", "exec", "unicorn", "-c", "unicorn.conf"]
