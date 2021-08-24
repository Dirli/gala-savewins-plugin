# gala-savewins-plugin
Gala plugin to restore windows after reboot

<p align="left">
    <a href="https://paypal.me/Dirli85">
        <img src="https://img.shields.io/badge/Donate-PayPal-green.svg">
    </a>
</p>

----

## Building and Installation

### You'll need the following dependencies to build:
* valac
* libglib2.0-dev
* libgee-0.8-dev
* libgala-dev
* libbamf3-dev
* meson

### How to build
    meson build --prefix=/usr
    ninja -C build
    sudo ninja -C build install

## Enable/disable the plugin (true | false)
    gsettings set org.gnome.SessionManager auto-save-session true

## If something went wrong
    cd [your lib directory]/gala/plugins
    sudo rm libgala-savewins.so
    reboot
