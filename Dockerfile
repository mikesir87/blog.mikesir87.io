FROM ruby:2.7 AS base
RUN gem install bundler
COPY Gemfile ./
RUN bundle install
WORKDIR /srv/jekyll

FROM base AS dev
CMD [ "jekyll", "serve", "--future", "--drafts", "--livereload", "-H", "0.0.0.0" ]

FROM base AS build
COPY . .
RUN jekyll

FROM nginx:alpine AS final
COPY --from=build /srv/_site /usr/share/nginx/html