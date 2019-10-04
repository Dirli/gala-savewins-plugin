# gala-savewins-plugin
Gala plugin to restore windows after reboot

The plugin is in a testing state.
Unfortunately, for correct work it is necessary to install forked wingpanel-indicator-session (https://github.com/Dirli/wingpanel-indicator-session)

Works with mutter-3.28 and mutter-3.30

## Building and Installation

You'll need the following dependencies to build:
* valac
* libglib2.0-dev
* libgee-0.8-dev
* libgala-dev
* libbamf3-dev
* meson

## How To Build

    meson build --prefix=/usr //debian,ubuntu --libdir=/usr/lib/x86_64-linux-gnu
    ninja -C build
    sudo ninja -C build install

## if something went wrong

    cd [your lib directory]/gala/plugins
    sudo rm libgala-savewins.so
    reboot
