# dbus-osx-examples

Examples and tutorials for setting up and using D-Bus, for OSX users.

The DBus tools are powerful, mature, and robust, but the project doesn't have an OSX maintainer at present. As a result, documentation and support for using DBus on OSX is scarce. This repository is my attempt to remedy that.

# Resources

- The `installation` directory contains a guide on various ways to configure and test DBus on Mac OSX.
- The `homebrew-patches` directory contains patches to DBus Homebrew formulae, already merged. It only exists for archival reasons. 
- The `examples` directory will eventually contains client/server implementations in various different languages. For now, it only has a (skeleton) Perl example.

# FAQ

- "A program I'm installing says it just needs `dbus-devel` or the DBus headers; how can I just get those?"
	- First: the `-devel` headers are installed along with the DBus homebrew package. They're in `$(brew --prefix dbus)/include`.
	- Second: most programs that require the `dbus-devel` also assume that DBus itself is a) installed, b) configured, c) running, and d) has certain common (usually Linux-specific) services online. On OSX, none of these things can be relied upon. For example, many programs that require `dbus-devel` use that package to compile interfaces for DBus services that respond to, for example, volume button press events, or CD drive load/unload events. Such programs will usually malfunction on OSX unless the DBus *services* they depend on are also present. Installing those services can require some research and work. To avoid these (often sneaky) issues, always check what `dbus-devel` is required for, and if there's a way to either prevent the compile-time requirement for DBus, or a way to disable the compiled application's dependence onf DBus. The assumption of DBus service availability based on header availability is, unfortunately, a common one.
- "[some `dbus-` shell command] keeps saying my syntax is invalid? I swear I'm doing it right! What gives?"
	- A common gotcha with the DBus commandline tools involves switches with values. It's common for many programs usage messages to indicate that a given switch takes a value by saying `usage: myprogram --myswitch=VALUE` or similar. What that *usually* means is that both `myprogram --myswitch=VALUE` and `myprogram --myswitch VALUE` (without the equals sign) are valid. In DBus this is not the case: **when a DBus commandline tool says to use `--switch=VALUE`, you *must* supply a verbatim equals sign on the commandline, with no spaces on either side.** This may also be affected by which version of `getopt` DBus was built with.
	- If that doesn't help, try reading the manpage for the command you're having trouble with. In a Homebrew install, manpages should already be installed, so e.g. `man dbus-test-tool` should Just Work. If not, or if you prefer HTML, the manuals are also available at https://dbus.freedesktop.org/doc; in the index, search for the name of the program you're interested in.
- "I know *how* to write a DBus service, but there are so many moving parts and I don't have a good sense of what the standards are. How *should* I write a DBus service?"
	- Check out the services running on your machine (`dbus-daemon --introspect`) for examples.
	- Check out the [design guidelines document](https://dbus.freedesktop.org/doc/dbus-api-design.html). It's great.