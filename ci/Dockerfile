FROM archlinux:base@sha256:e43f1fd80e073992c5f173efbbbf65144170bf60aeb7369940087d63eacea8f4
RUN pacman -Syu --noconfirm --needed python nodejs git quickshell qt6-5compat qt6-multimedia imagemagick cage dbus ttf-dejavu
ARG OMARCHY_COMMIT=0a7beb7d6fe2b677bdc57ff05518b073b2d6ee60
RUN git init /opt/omarchy && git -C /opt/omarchy remote add origin https://github.com/omacom/omarchy.git \
    && git -C /opt/omarchy fetch --depth 1 origin "$OMARCHY_COMMIT" \
    && git -C /opt/omarchy checkout --detach FETCH_HEAD
ENV FUTBAR_SHELL_ROOT=/opt/omarchy/shell
ENV WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
ENV QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1
WORKDIR /work
CMD ["bash", "ci/run-runtime.sh"]
