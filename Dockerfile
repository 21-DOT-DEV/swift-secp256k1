# Use an official Swift runtime image
FROM swift:5.2

ADD . /LinuxTests

WORKDIR /LinuxTests

# Install related packages
RUN swift test