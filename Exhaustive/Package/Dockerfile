# Use an official Swift runtime image
FROM swift:5.8.0

# Copies the root directory of the repository into the image's filesystem at `/LinuxTests`
ADD . /LinuxTests

# Set the working directory to `/LinuxTests/Exhaustive/zkp`
WORKDIR /LinuxTests/Exhaustive/zkp

# Execute Linux test suite
RUN swift test
