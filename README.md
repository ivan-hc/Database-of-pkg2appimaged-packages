This repository is needed to build various AppImage packages from the Debian Stable/Oldstable repository or from some PPAs for Ubuntu to made them easily downloadable by the two Application Managers "[AM](https://github.com/ivan-hc/AM-Application-Manager)"
and "[AppMan](https://github.com/ivan-hc/AppMan)", and if needed from any other AppImage package manager.

# How to integrate these AppImages into the system
The easier way is to install "AM" on your PC, see [ivan-hc/AM-application-manager](https://github.com/ivan-hc/AM-application-manager) for more.

Alternatively, you can install the AppImage `$APP` it this way:

    wget https://raw.githubusercontent.com/ivan-hc/AM-Application-Manager/main/programs/x86_64/$APP
    chmod a+x ./$APP
    sudo ./$APP
The AppImage will be installed in /opt/$APP as `$APP`, near other files.
### Update

    /opt/$APP/AM-updater
### Uninstall

    sudo /opt/$APP/remove
