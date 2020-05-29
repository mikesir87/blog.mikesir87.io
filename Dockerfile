FROM jekyll/jekyll AS base
RUN gem install bundler:1.16.1
COPY Gemfile Gemfile.lock ./
RUN bundle install

FROM base AS dev
CMD [ "jekyll", "serve", "--future", "--drafts", "--livereload" ]

FROM base AS build
COPY . .
RUN jekyll

FROM nginx:alpine AS final
COPY --from=build /srv/_site /usr/share/nginx/html