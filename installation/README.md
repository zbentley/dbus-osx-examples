# Overview

This document details how to install and configure the DBus ecosystem on OSX. This ecosystem consists of the DBus session and system daemons, `libdbus` and other DBus-related libraries, and integration with [`launchd`](http://launchd.info/) so that DBus can be activated as a first-class OSX service.

# Installation

Installing DBus is simple using [homebrew](brew.sh), the OSX package manager:

```bash
brew install dbus
```

That command will install DBus into ___

Its default configuration files will be stored in ___

It will expect socket activation and other snap-in configurations in ___

# Initial Configuration

### Session Bus
To tell launchd about dbus, copy the files into the appropriate `LaunchAgents` directory. If other users on your computer are unlikely to use or care about DBus, symlink the appropriate file(s) for the daemon you plan on using into `~/Library/LaunchAgents` (create the directory if it doesn't exist). If you want to install it in the global/system-internal-services location, or if you plan on configuring or running a system bus, put it in `/Library/LaunchAgents`. 

The Homebrew formula suggests the following command:

```bash
ln -sfv /usr/local/opt/d-bus/*.plist ~/Library/LaunchAgents
```

However, there are some pointless lines in the distributed `org.freedesktop.dbus-session.plist` file that comes with the DBus Homebrew package. Unless you're running OSX < 10.8, you can omit some cruft from that file and prevent launchd from spamming a lot of your logs with deprecated-feature notifications. To do that, don't do the above symlink operation, and instead install the `org.freedesktop.dbus-session.plist`  included with this repository into `~/Library/LaunchAgents`.

Whichever of the two above alternatives you use, you will then need to register the service with launchd:

```bash
launchctl load ~/Library/LaunchAgents/org.freedesktop.dbus-session.plist
```

### System Bus

Only the `dbus-session` session bus configuration file comes with the Homebrew package. You can build a system bus configuration file and launch it via the system-level launchd process if you want. 

# Manually Launching Daemons

# Compiling on OSX

```bash
brew install libtool autoconf automake
```

# Resources and Other Links

- [Configuring DBus with `launchd`](http://blog.roderickmann.org/2015/03/using-dbus-on-os-x-yosemite/)
- https://bugs.freedesktop.org/show_bug.cgi?id=94494
