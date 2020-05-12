FROM ruby:2-alpine

RUN apk update && apk add --update --no-cache \
  # Utilities
  bash \
  # C compiler etc
  build-base \
  # Support git sources in the Gemfile
  git openssh-client \
  # Used by ActiveStorage
  imagemagick \
  # Dependencies for Nokogiri
  libxml2-dev \
  libxslt-dev \
  # Webpacker and friends
  nodejs nodejs-npm yarn \
  # Timezone data for Ruby's TZInfo library
  tzdata \
  # Used by the pg gem
  postgresql-dev

WORKDIR /app

# Setup environment for cached bundle
ENV BUNDLE_PATH=/gems \
    BUNDLE_BIN=/gems/bin \
    GEM_HOME=/gems
ENV PATH="${BUNDLE_BIN}:${PATH}"

COPY Gemfile Gemfile.lock .ruby-version ./

# Provide private key for getting private repository
COPY config/deploy/id_rsa /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa
RUN touch /root/.ssh/known_hosts
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts

# Bundle
RUN apk --update add --virtual build-dependencies \
    # C compiler etc
    build-base ruby-dev libc-dev linux-headers && \
    cd /app ; \
    bundle --binstubs="$BUNDLE_BIN" --without development test && \
    apk del build-dependencies

# Install JS dependencies before copying app code to use layer caching.
# Note: In JS heavy apps consider an approach similar to bundler.
COPY package.json yarn.lock ./
RUN yarn

COPY . .

ARG ASSET_HOST
ENV RAILS_ENV production
ENV RAILS_SERVE_STATIC_FILES true
RUN bundle exec rake assets:precompile
RUN rm -Rf node_modules

# We use a custom script as entry point to manage our bundle cache
COPY ./docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh && mkdir -p tmp/pids
ENTRYPOINT ["/docker-entrypoint.sh"]
