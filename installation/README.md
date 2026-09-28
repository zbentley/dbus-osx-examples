# Overview

This document details how to install and configure the D-Bus ecosystem on macOS. This ecosystem consists of the D-Bus session and system daemons, `libdbus` and other D-Bus-related libraries, and integration with [`launchd`](https://launchd.info/) so that D-Bus can be run as a first-class macOS service.

# Installation

Installing D-Bus is simple using [Homebrew](https://brew.sh/), the macOS package manager:

```bash
brew install dbus
```

That command installs D-Bus under the Homebrew prefix. The prefix depends on your hardware: `/opt/homebrew` on Apple Silicon Macs and `/usr/local` on Intel Macs. Rather than hardcoding either one, the commands in this guide use `$(brew --prefix)` (the Homebrew prefix) and `$(brew --prefix dbus)` (the D-Bus package directory, `$(brew --prefix)/opt/dbus`).

### File Locations

- Default session and system bus configuration files: `$(brew --prefix dbus)/share/dbus-1/session.conf` and `system.conf`.
- Local configuration overrides and service policy snippets: `$(brew --prefix)/etc/dbus-1/` (`session.d/`, `system.d/`, `session-local.conf`, `system-local.conf`).
- `launchd` `.plist` files for both the session bus (`org.freedesktop.dbus-session.plist`) and the system bus (`org.freedesktop.dbus-system.plist`) in the package directory; they can be listed with `ls $(brew --prefix dbus)/*.plist`.
- The system bus socket: `$(brew --prefix)/var/run/dbus/system_bus_socket`.
- Headers are in `$(brew --prefix dbus)/include/dbus-1.0` and `$(brew --prefix dbus)/lib/dbus-1.0/include`. The easiest way to get the right compiler flags is `pkg-config --cflags --libs dbus-1`.
	- For an example of how to detect and use D-Bus headers properly in a flexible way that works without trickery on macOS and many other platforms, see the `autoconf` setup used in the [`offlinefs`](https://github.com/darkdragon-001/offlinefs) project.

# Initial Configuration

### Session Bus

You can run the session bus on your system with the configuration files included in the Homebrew D-Bus distribution. There are a few ways to do this.

Out of the box on macOS, D-Bus is configured to work with [`launchd`](https://launchd.info/), so it's easiest to use that (the first method below does). More information on the D-Bus/`launchd` integration can be found in the upstream D-Bus documentation, [`README.launchd`](https://gitlab.freedesktop.org/dbus/dbus/-/blob/main/README.launchd).

#### Using `launchd` Directly

This is the recommended way to run the session bus.

> **Unverified on current macOS.** In a test on macOS 27.2 (arm64) with dbus 1.16.2_1, `launchctl bootstrap` accepted the packaged plist without error, but `launchctl getenv DBUS_LAUNCHD_SESSION_BUS_SOCKET` stayed empty and `dbus-send --session` could not connect. This is still being investigated. Until it's resolved, [manually launching the session bus](#manually-launching-the-session-bus) is the most reliable option.

First, copy (or symlink) the session bus `.plist` into your per-user `LaunchAgents` directory (create the directory if it doesn't exist):

```bash
mkdir -p ~/Library/LaunchAgents
ln -sfv "$(brew --prefix dbus)/org.freedesktop.dbus-session.plist" ~/Library/LaunchAgents/
```

Then register it with `launchd` for your login session:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/org.freedesktop.dbus-session.plist
```

Other useful commands:

- Restart it: `launchctl kickstart -k gui/$(id -u)/org.freedesktop.dbus-session`
- Check its status: `launchctl print gui/$(id -u)/org.freedesktop.dbus-session`
- Unregister it: `launchctl bootout gui/$(id -u)/org.freedesktop.dbus-session`

The session bus will now start automatically at each login. `launchctl load` and `launchctl unload` still exist, but Apple considers them legacy; `bootstrap` and `bootout` are the current equivalents and give more useful errors.

#### About `brew services`

`brew install dbus` suggests running `brew services start dbus`. With the current formula (dbus 1.16.2) that command fails with `Formula dbus has not implemented #plist, #service or provided a locatable service file` (see [issue #4](https://github.com/zbentley/dbus-osx-examples/issues/4)). Use the `launchctl` steps above instead.

Do **not** work around it by running `brew services` with `sudo`. The session bus belongs to your login session, and running Homebrew as root can leave root-owned files in the Homebrew prefix that break later `brew` commands.

#### Manually Launching the Session Bus

D-Bus needs to have a main [Unix domain socket](https://en.wikipedia.org/wiki/Unix_domain_socket) in order to start.

If starting it manually, you'll have to give it a path to a socket. To set this up, do the following:

1. Pick a location to use for the socket. I use `/tmp/dbus/$USER.session.usock`.
2. Set that location in an environment variable of your choice (I use `MY_SESSION_BUS_SOCKET`), either by `export`ing it, setting it in one of your shell profile files, or prepending it to all commands that need to communicate with D-Bus (e.g. `MY_SESSION_BUS_SOCKET=/path/to/my/socket some_command_that_uses_dbus`).
3. Ensure the folder exists (`mkdir -p "$(dirname "$MY_SESSION_BUS_SOCKET")"`), and has permissions such that all the user(s) you want to connect to this instance of the session bus can read and write to it.

Starting the daemon in manual mode can be a bit confusing: the default D-Bus config on Homebrew/macOS assumes that the socket will be provided to D-Bus in an environment variable called `DBUS_LAUNCHD_SESSION_BUS_SOCKET` that is *set by `launchd`.* As a result, if you just try to start D-Bus with that variable set, it will fail with an error like `Check-in failed: No such process`. This indicates that D-Bus can't talk to `launchd` to get the environment variable (D-Bus isn't reading the variable out of its *own* environment; it's reading it out of *`launchd`'s* environment-management system).

You can change how D-Bus tries to get its main socket address in one of two ways:

1. By changing the session daemon config. The session bus config used by default is `$(brew --prefix dbus)/share/dbus-1/session.conf`; search for the value of the `<listen>` configuration key, and replace it with the result of `echo unix:path=$MY_SESSION_BUS_SOCKET`. Rather than editing that file (Homebrew will overwrite it on upgrade), make a copy and supply it to the `dbus-daemon` command with the `--config-file` switch.
	- If you choose this method, the daemon can be started via `dbus-daemon --config-file=/path/to/your/session.conf`.
2. By overriding the config-file-set value when you start the daemon, with the `--address` switch. This is easier.
	- If you choose this method, the daemon can be started via `dbus-daemon --session --nofork --address=unix:path=$MY_SESSION_BUS_SOCKET`

The `--nofork` argument is useful when testing daemons: it keeps the daemon from backgrounding itself, which makes it easier to watch and start/stop via CTRL+C for testing.

If the daemon fails to come up, and indicates that a socket is in use, make sure no other session daemons are running, and make sure that the socket doesn't already exist (`rm $MY_SESSION_BUS_SOCKET`).

Programs that should talk to a manually-started daemon need to be told where it is, usually by setting `DBUS_SESSION_BUS_ADDRESS=unix:path=$MY_SESSION_BUS_SOCKET` in their environment.

### System Bus

The Homebrew package ships a `launchd` daemon `.plist` for the system bus, `org.freedesktop.dbus-system.plist`. It runs `dbus-daemon --system` as the `daemon` user, using the configuration at `$(brew --prefix dbus)/share/dbus-1/system.conf`, and listens on `$(brew --prefix)/var/run/dbus/system_bus_socket`.

To start the system bus now and on every boot, install and activate that daemon (these are the steps `brew info dbus` prints):

```bash
sudo cp -f "$(brew --prefix dbus)/org.freedesktop.dbus-system.plist" /Library/LaunchDaemons
sudo launchctl bootstrap system /Library/LaunchDaemons/org.freedesktop.dbus-system.plist
```

If it's already installed and running, restart it with:

```bash
sudo launchctl kickstart -k system/org.freedesktop.dbus-system
```

To remove it, run `sudo launchctl bootout system/org.freedesktop.dbus-system` and delete the `.plist` from `/Library/LaunchDaemons`.

Policy for services on the system bus goes in `$(brew --prefix)/etc/dbus-1/system.d/`. Most people never need a system bus on macOS; only set one up if a program you're using explicitly requires it.

[`system.conf.envsubst`](system.conf.envsubst) in this directory is an older hand-rolled system bus config template from before Homebrew shipped one. It's kept for reference, but the packaged `system.conf` should be preferred.

# Testing a D-Bus Daemon

Once you have a running daemon, you can test it by doing the following.

1. Start a test service that echoes RPC request content back to the sender. Do `dbus-test-tool echo --session --name=com.$USER.echo` (or `--system` if you're using a system bus). It should start and block waiting for a request.
	- If you started the daemon manually (without `launchd`), set `DBUS_SESSION_BUS_ADDRESS=unix:path=$MY_SESSION_BUS_SOCKET` in the environment of both this command and the `dbus-send` command below so they can find it.
2. In another terminal, do `dbus-send --session --print-reply --dest=com.$USER.echo /my/test/object my.test.service.TestInterface.TestMethod string:'testdata3'`. You should receive a successful return code and a line like `method return time=1478884698.245102 sender=:1.0 -> destination=:1.25 serial=15 reply_serial=2`.
	- That `dbus-send` command will send a message to the connection named `com.$USER.echo` (which is what we told `dbus-test-tool` to listen with; this could also be a unique connection name like `:1.12`), addressing the object `/my/test/object`, calling the `TestMethod` function in the interface `my.test.service.TestInterface`, and supplying a payload of one string with the value "testdata3". Neither the object, the method, nor the interface actually exist, but the `echo` test service doesn't care; it responds with an empty reply to everything.

That's just an aliveness test of the bus itself. It doesn't do anything "real" (custom services, method calls, return values, etc). See the other guides in this repository for help with that.

# Compiling on macOS

To build D-Bus from source via Homebrew, do `brew install --build-from-source dbus` (or `brew install --HEAD dbus` for the latest upstream `main` branch).

To build D-Bus yourself, D-Bus now uses [Meson](https://mesonbuild.com/) (the old autotools build is gone). Install the build tools with `brew install meson ninja pkgconf`, get the sources from https://gitlab.freedesktop.org/dbus/dbus (or a release tarball from https://dbus.freedesktop.org/releases/dbus/), and then:

```bash
meson setup build
meson compile -C build
meson install -C build
```

See `INSTALL` in the source tree for the available options (`meson configure build` also lists them). Homebrew's own build is a good reference; you can see it with `brew cat dbus`.

### Manpage/XML-Related Build Errors

If you build with XML documentation enabled (`-Dxml_docs=enabled`) and have a Homebrew (or MacPorts)-installed version of `xmlto` or any of the `docbook` packages, you may run into a build-breaking issue in which manpages fail to build with errors like `I/O error : Attempt to load network entity`.

The *workaround* for this problem is to disable the XML docs with `-Dxml_docs=disabled`.

The *fix* for this problem is to set the `XML_CATALOG_FILES` environment variable to point to a current `docbook` catalog. If your `xmlto` and `docbook` have been installed via Homebrew, `export XML_CATALOG_FILES="$(brew --prefix)/etc/xml/catalog"` should do the trick (this is what the Homebrew formula itself does). Otherwise, try to figure out where the catalogs are stored.

# Resources and Other Links

- The manpages for all programs used in this tutorial, e.g. `man dbus-send`. See `README.md` in the root of this repository for more info on where to find manuals.
- The D-Bus tutorial: https://dbus.freedesktop.org/doc/dbus-tutorial.html
- D-Bus and `launchd` upstream notes: https://gitlab.freedesktop.org/dbus/dbus/-/blob/main/README.launchd
- The Homebrew formula for D-Bus: https://github.com/Homebrew/homebrew-core/blob/main/Formula/d/dbus.rb
- D-Bus upstream issue tracker: https://gitlab.freedesktop.org/dbus/dbus/-/issues
