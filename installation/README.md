# Overview

This document details how to install and configure the DBus ecosystem on OSX. This ecosystem consists of the DBus session and system daemons, `libdbus` and other DBus-related libraries, and integration with [`launchd`](http://launchd.info/) so that DBus can be activated as a first-class OSX service.

# Installation

Installing DBus is simple using [homebrew](brew.sh), the OSX package manager:

```bash
brew install dbus
```

That command will install DBus into the default Homebrew installation directory (usually `/usr/local/`); you can access that directory via `brew --prefix dbus`.

### File Locations

- Default session and system bus configuration files: `$(brew --prefix dbus)/share`
- A `.plist` file for linking the DBus session daemon with the standard OSX [`launchd`](http://launchd.info/) init system in the base install directory; they can be enumerated with `ls $(brew --prefix dbus)/*.plist`.
	- As of this writing there is not a `launchd` file for the `system` daemon.
- Headers and sources are in `$(brew --prefix dbus)/include`. Custom library paths are usually not necessary for programs on OSX to compile against DBus (I've managed to compile a few, at least).
	- For an example of how to detect and use DBus headers properly in a flexible way that works without trickery on OSX and many other platforms, see the `autoconf` setup used in the [`offlinefs`](https://github.com/darkdragon-001/offlinefs) project.

# Initial Configuration

### Session Bus

You can run the session bus on your system with the configuration files included in the Homebrew DBus distribtion. There are a few ways to do this.

Out of the box on OSX, DBus is configured to work with [`launchd`](http://launchd.info/), so it's easiest to use that (the first two methods below do). More information on the DBus-`launchd` integration can be found in the DBus documentation, [here](https://github.com/brianmcgillion/DBus/blob/master/README.launchd).


#### Using Homebrew Service Management

This is by far the easiest way to get a session daemon up and running. Do:

```bash
brew services start dbus
```

That will set the DBus daemon to start at user login. `brew services stop dbus` will remove it from the service registry entirely.

To see the `launchctl` commands that `brew services` is running, supply the `--verbose` switch to the any `brew services` command.

#### Using `launchd` Directly

The below steps basically do what 

To tell launchd about dbus, copy the files into the appropriate `LaunchAgents` directory. If other users on your computer are unlikely to use or care about DBus, symlink the appropriate file(s) for the daemon you plan on using into `~/Library/LaunchAgents` (create the directory if it doesn't exist). If you want to install it in the global/system-internal-services location, or if you plan on configuring or running a system bus, put it in `/Library/LaunchAgents`. 

The Homebrew formula suggests the following command:

```bash
ln -sfv /usr/local/opt/dbus/*.plist ~/Library/LaunchAgents
```

However, there are some pointless lines in the distributed `org.freedesktop.dbus-session.plist` file that comes with the DBus Homebrew package. Unless you're running OSX < 10.8, you can omit some cruft from that file and prevent launchd from spamming a lot of your logs with deprecated-feature notifications. To do that, don't do the above symlink operation, and instead install the `org.freedesktop.dbus-session.plist`  included with this repository into `~/Library/LaunchAgents`.

Whichever of the two above alternatives you use, you will then need to register the service with launchd:

```bash
launchctl load ~/Library/LaunchAgents/org.freedesktop.dbus-session.plist
```

#### Manually Launching the Session Bus

DBus needs to have a main [Unix domain socket](https://en.wikipedia.org/wiki/Unix_domain_socket) in order to start.

If starting it manually, you'll have to give it a path to a socket. To set this up, do the following:

1. Pick a location to use for the socket. I use `/tmp/dbus/$USER.session.usock`.
2. Set that location in an environment variable of your choice (I use `MY_SESSION_BUS_SOCKET`), either by [`export`]()ing it, setting it in one of your shell `.*profile` files, or prepending it to all commands that need to communicate with DBus (e.g. `# ~> MY_SESSION_BUS_SOCKET=/path/to/my/socket some_command_that_uses_dbus).
2. Ensure the folder exists (`mkdir $(dirname $MY_SESSION_BUS_SOCKET)`), and has permissions such that all te user[s] you want to connect to this instance of the session bus can read and write to it.

Starting the daemon in manual mode can be a bit confiusing: the default DBus config on Homebrew/OSX assumes that the socket will be provided to DBus in an environment variable called `DBUS_LAUNCHD_SESSION_BUS_SOCKET` that is *set by `launchd`.* As a result, if you just try to start DBus with that variable set, it will fail with an error like `Check-in failed: No such process`. This indicates that DBus can't talk to `launchd` to get the environment variable (DBus isn't reading the variable out of its *own* environment; it's reading it out of *`launchd`'s* environment-management system).

You can change how DBus tries to get its main socket address in one of two ways:

1. By changing the session daemon config. The session bus config used by default is in `$(brew --prefix dbus)/share/dbus.1/session.conf`; search for the value of the `<listen>` configuration key, and replace it with the result of `echo unix:path=$MY_SESSION_BUS_SOCKET`. You can either edit that file (make sure to revert your edits if you ever do want to use `launchd` to manage DBus), or make a new one and supply that file to the `dbus-daemon` command with the `--config-file` switch.
	- If you choose this method, the daemon can be started via `dbus-daemon --session` or `dbus-launch`.
2. By overriding the config-file-set value when you start the daemon, with the `--address`. This is easier.
	- If you choose this method, the daemon can be started via `dbus-daemon --session --nofork --address unix:path=$MY_SESSION_BUS_SOCKET`

The `--nofork` argument is useful when testing daemons: it keeps the daemon from backgrounding itself, which makes it easier to watch and start/stop via CTRL+C for testing.

If the daemon fails to come up, and indicates that a socket is in use, make sure no other session daemons are running, and make sure that the socket doesn't already exist (`rm $MY_SESSION_BUS_SOCKET`).

### System Bus

Only the `dbus-session` session bus `launchd` service `.plist` file comes with the Homebrew package. You can build a system bus configuration file and launch it via the system-level launchd process if you want. If you do so, it will use the DBus configuration at `$(brew --prefix dbus)/share/dbus-1/system.conf`.


# Testing a DBus Daemon

Once you have a running daemon, you can test it by doing the following.

1. Start a test service that echos RPC request content back to the sender. Do `dbus-test-tool echo --session --name=com.$USER.echo` (or `--system` if you're using a system bus). It should start and block waiting for a request.
	- Note that this will *not* work if you have started the DBus daemon in "manual" mode (without `launchd`). `dbus-test-tool` provides no way to override the assumption that `launchd` will be used to acquire the address of a running DBus daemon. This is probably a bug. If you want to run a test service with a manually-started daemon, you'll have to write the service yourself (see other files in this repo for examples/instructions on how to do that).
2. In another terminal, do `dbus-send --session --print-reply --dest=com.$USER.echo /my/test/object my.test.service.TestInterface.TestMethod string:'testdata3'`. You should receive a successful return code; a line like `method return time=1478884698.245102 sender=:1.0 -> destination=:1.25 serial=15 reply_serial=2`.
	- That `dbus-send` command will send a message to the connection named `com.$USER.echo` (which is what we told `dbus-test-tool` to listen with; this could also be an anonymous connection name like `1:12`), addressing the object `/my/test/object`, and calling the `TestMethod` function in the interface `my.test.service.TestInterface`, and supplying a payload of one string with the value "testdata3". Neither the object, the method, nor the interface actually exist, but the `echo` test service doesn't care; it responds with an empty reply to everything.

That's just an aliveness test of the bus itself. It doesn't do anything "real" (custom services, method calls, return values, etc). See the other guides in this repository for help with that.

# Compiling on OSX

To compile DBus via Homebrew, do `brew install dbus --HEAD`.

To compile DBus the normal way, make sure you have `libtool`, `automake`, `autoconf`, and `autoconf-archive` installed. Optionally, you may want an X server or `doxygen`. Then, get the sources from https://anongit.freedesktop.org/git/dbus/dbus.git, and follow the directions in `INSTALL`.

### Manpage/XML-Related Build Errors

If you're compiling manually, but have a Homebrew (or MacPort)-installed version of `xmlto` or any of the `docbook` packages, you may run into a build-breaking issue in which manpages fail to build with errors like `I/O error : Attempt to load network entity`.

The *workaround* for this problem is to configure with `--disable-xml-docs` (which I think is the default; I had to explicitly enable them, at least).

The *fix* for this problem is to set the `XML_CATALOG_FILES` environment variable to point to a directory with a current `docbook` catalog in it. If your `xmlto` and `docbook` have been installed via Homebrew, `export XML_CATALOG_FILES="/usr/local/etc/xml/catalog"` should do the trick (according to [this issue report](https://github.com/Homebrew/legacy-homebrew/issues/21040), at least). Otherwise, try to figure out where the catalogs are stored. [This article](https://www.mercurial-scm.org/wiki/MacOSXTools) may help.

# Resources and Other Links

- The manpages for all programs used in this tutorial, e.g. `man dbus-send`. See `README.md` in the root of this tutorial for more info on where to find manuals.
- The `dbus` tutorial: https://dbus.freedesktop.org/doc/dbus-tutorial.html
- Configuring DBus with `launchd`: http://blog.roderickmann.org/2015/03/using-dbus-on-os-x-yosemite/
- Issue for fixing included `.plist` files on older OSX versions: https://bugs.freedesktop.org/show_bug.cgi?id=94494
