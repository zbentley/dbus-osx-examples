# dbus-osx-examples

Examples and tutorials for setting up and using D-Bus, for macOS users.

The D-Bus tools are powerful, mature, and robust, but documentation and support for using D-Bus on macOS is scarce. This repository is my attempt to remedy that.

# Resources

- The `installation` directory contains a guide on various ways to configure and test D-Bus on macOS.
- The `homebrew-patches` directory contains patches to the D-Bus Homebrew formula. They have been merged upstream (the current formula applies the same change, from [D-Bus MR 179](https://gitlab.freedesktop.org/dbus/dbus/-/merge_requests/179)), so this directory only exists for archival reasons.
- The `examples` directory will eventually contain client/server implementations in various different languages. For now, it only has a (skeleton) Perl example; see its [README](examples/perl/net-dbus/README.md) for how to run it.

# FAQ

- "A program I'm using which interacts with dbus can't connect! What should I do?"
	- A local dbus daemon likely is not running; check `ps -ef | grep [d]bus` to be sure.
	- The easiest way to get a local dbus daemon running is to use the [Homebrew](https://brew.sh/) package manager. If you haven't already, run `brew install dbus`. 
	- If dbus is already installed, ensure it is running (`launchctl print gui/$(id -u)/org.freedesktop.dbus-session` shows whether it is). If it's not running, register it with `launchd` so it starts now and at every login; the [installation guide](installation/README.md#using-launchd-directly) has the two commands. `brew services start dbus`, which Homebrew suggests, currently fails for D-Bus, and running it with `sudo` causes more problems than it solves.
- "A program I'm installing says it just needs `dbus-devel` or the D-Bus headers; how can I just get those?"
	- First: the `-devel` headers are installed along with the D-Bus Homebrew package. They're in `$(brew --prefix dbus)/include/dbus-1.0` (plus `$(brew --prefix dbus)/lib/dbus-1.0/include` for the platform-specific `dbus-arch-deps.h`); `pkg-config --cflags --libs dbus-1` prints the right flags.
	- Second: most programs that require the `dbus-devel` also assume that D-Bus itself is a) installed, b) configured, c) running, and d) has certain common (usually Linux-specific) services online. On macOS, none of these things can be relied upon. For example, many programs that require `dbus-devel` use that package to compile interfaces for D-Bus services that respond to, for example, volume button press events, or CD drive load/unload events. Such programs will usually malfunction on macOS unless the D-Bus *services* they depend on are also present. Installing those services can require some research and work. To avoid these (often sneaky) issues, always check what `dbus-devel` is required for, and if there's a way to either prevent the compile-time requirement for D-Bus, or a way to disable the compiled application's dependence on D-Bus. The assumption of D-Bus service availability based on header availability is, unfortunately, a common one.
- "[some `dbus-` shell command] keeps saying my syntax is invalid? I swear I'm doing it right! What gives?"
	- A common gotcha with the D-Bus commandline tools involves switches with values. It's common for many programs usage messages to indicate that a given switch takes a value by saying `usage: myprogram --myswitch=VALUE` or similar. What that *usually* means is that both `myprogram --myswitch=VALUE` and `myprogram --myswitch VALUE` (without the equals sign) are valid. In D-Bus this is not the case: **when a D-Bus commandline tool says to use `--switch=VALUE`, you *must* supply a verbatim equals sign on the commandline, with no spaces on either side.** This may also be affected by which version of `getopt` D-Bus was built with.
	- If that doesn't help, try reading the manpage for the command you're having trouble with. In a Homebrew install, manpages should already be installed, so e.g. `man dbus-test-tool` should Just Work. If not, or if you prefer HTML, the manuals are also available at https://dbus.freedesktop.org/doc; in the index, search for the name of the program you're interested in.
- "I know *how* to write a D-Bus service, but there are so many moving parts and I don't have a good sense of what the standards are. How *should* I write a D-Bus service?"
	- Check out the services running on your machine for examples. `dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames` lists the names on the session bus, and `dbus-send --session --print-reply --dest=SOME.NAME / org.freedesktop.DBus.Introspectable.Introspect` shows what a given service exposes. (`dbus-daemon --introspect` only prints the bus daemon's own interface.)
	- Check out the [design guidelines document](https://dbus.freedesktop.org/doc/dbus-api-design.html). It's great.
