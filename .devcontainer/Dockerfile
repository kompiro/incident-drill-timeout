FROM mcr.microsoft.com/devcontainers/ruby:3.1-bullseye

RUN gem update --system

# Install hey
RUN curl -O https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 \
  && mv hey_linux_amd64 /usr/local/bin/hey \
  && chmod +x /usr/local/bin/hey
