FROM buildkite/plugin-tester:latest@sha256:476a1024936901889147f53d2a3d8e71e99d76404972d583825514f5608083dc
# openssh needing for ssh agent testing, procps install updates default busybox ps command for pre-exit hook ps -p option
RUN apk --update add openssh-client procps
