# How Programs Find the Session Bus on macOS

On Linux, programs usually find the session bus through the `DBUS_SESSION_BUS_ADDRESS` environment variable, a well-known socket at `$XDG_RUNTIME_DIR/bus`, or by running `dbus-launch --autolaunch`. None of these apply by default on macOS. This document explains what happens instead, why `dbus-launch --autolaunch` fails, and how to point a program that can't find the bus at the right place.

If you haven't set up a session bus yet, do that first; see [the installation guide](README.md).

> **Short version for current macOS.** On macOS 27.2 with Homebrew dbus 1.16.2, the launchd integration described below does not give programs a usable bus: the job loads, but launchd no longer publishes its socket where clients look for it. What does work is starting a session bus yourself and exporting its address; see [Fix: Start a Bus and Tell Programs Where It Is](#fix-start-a-bus-and-tell-programs-where-it-is).

## How the launchd Integration Is Meant to Work

The Homebrew session bus is designed to be started by `launchd`, not by your shell or login session. The pieces fit together like this:

1. **launchd owns the socket.** The `org.freedesktop.dbus-session.plist` launch agent has a `Sockets` entry with a `SecureSocketWithKey` of `DBUS_LAUNCHD_SESSION_BUS_SOCKET`. When the agent is loaded, launchd creates a Unix socket at a random path (something like `/private/tmp/com.apple.launchd.AbCdEf1234/unix_domain_listener`) and publishes that path in *launchd's* environment under the name `DBUS_LAUNCHD_SESSION_BUS_SOCKET`.
2. **The daemon is started on demand.** `dbus-daemon` is not necessarily running just because the agent is loaded. launchd starts it when the first client connects to the socket. So `ps -ef | grep [d]bus` can come up empty on a perfectly working setup; the check that matters is whether the socket exists (below).
3. **The daemon checks in with launchd.** Homebrew's `session.conf` listens on `launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET`. That tells `dbus-daemon` to ask launchd for the already-open socket instead of creating its own. This is why starting `dbus-daemon --session` by hand fails with `Check-in failed: No such process`: the daemon wasn't started by launchd, so there is nothing to check in with. (See "Manually Launching the Session Bus" in the [installation guide](README.md) for how to run it without launchd.)
4. **Clients ask launchd for the socket path.** When `DBUS_SESSION_BUS_ADDRESS` is not set, `libdbus` on macOS uses the default address `launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET`, looks the path up in launchd's environment, and connects to it as `unix:path=<that path>`.

The important detail in steps 1 and 4 is that `DBUS_LAUNCHD_SESSION_BUS_SOCKET` lives in launchd's environment, not your shell's. It usually won't show up in `env`. To see it, ask launchd:

```bash
launchctl getenv DBUS_LAUNCHD_SESSION_BUS_SOCKET
```

If that prints a path, the session bus agent is loaded and clients that understand launchd will find it.

**On macOS 27.2 this prints nothing, even with the agent loaded.** In testing with Homebrew dbus 1.16.2, `launchctl bootstrap gui/$(id -u) $(brew --prefix dbus)/org.freedesktop.dbus-session.plist` loaded the job, but `launchctl getenv DBUS_LAUNCHD_SESSION_BUS_SOCKET` stayed empty and `dbus-send --session` still failed. The socket path only shows up in the output of `launchctl print gui/$(id -u)`. Pointing `DBUS_SESSION_BUS_ADDRESS` at that path by hand hasn't been tested. (`brew services start dbus` also fails with this version; see issue #4.)

The socket path changes every time the agent is loaded (typically once per login), so never hardcode it anywhere.

## Why `dbus-launch --autolaunch` Fails

"Autolaunch" is a mechanism for finding (or starting) a session bus that belongs to an X11 display. `dbus-launch --autolaunch` records the bus address on the X server, so every program on the same display shares one bus. It needs `dbus-launch` to be built with X11 support.

Homebrew's `dbus` is built without X11, and a normal macOS desktop has no X display anyway. So when no session bus address can be found, autolaunch fails. With Homebrew's dbus 1.16.2, running `dbus-launch --autolaunch=...` prints this and exits with status 1:

```
No existing session bus was found, and X11 autolaunch support was disabled at compile time.
```

A `libdbus` client such as `dbus-send`, when it can't find the bus, prints a message that names the fix:

```
Using X11 for dbus-daemon autolaunch was disabled at compile time, verify that org.freedesktop.dbus-session.plist is loaded or set your DBUS_SESSION_BUS_ADDRESS instead
```

Programs hit this when there's no `DBUS_SESSION_BUS_ADDRESS` and they can't get a bus from launchd (which, on current macOS, is all of them). The usual culprit is GLib's GDBus (used by GTK/GNOME programs such as Fractal, `gnome-keyring`, `gsettings` and friends). When `DBUS_SESSION_BUS_ADDRESS` is unset, GDBus falls back to autolaunching via `dbus-launch`. Newer GLib releases ask launchd for `DBUS_LAUNCHD_SESSION_BUS_SOCKET` on macOS first, but that only helps where launchd actually publishes the variable, which it doesn't on macOS 27.2. Either way, the fix below works.

## Fix: Start a Bus and Tell Programs Where It Is

Every D-Bus client library honors `DBUS_SESSION_BUS_ADDRESS`, and if it's set they skip launchd and autolaunch entirely. So the reliable fix is to start a session bus yourself and export its address.

This was tested on macOS 27.2 with Homebrew dbus 1.16.2:

```bash
DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address=1 --address=unix:tmpdir=$TMPDIR)
export DBUS_SESSION_BUS_ADDRESS
```

`--address` overrides the `launchd:` listen address in Homebrew's `session.conf` (which would otherwise fail with `Check-in failed`), `unix:tmpdir=$TMPDIR` has the daemon create a fresh socket in your per-user temp folder, and `--print-address=1` prints the resulting `unix:path=...` address for you to export. To also print the daemon's PID (so you can `kill` it later), add `--print-pid=1`; the address is the first line of output and the PID the second.

To check that the address works:

```bash
dbus-send --session --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListNames
```

That should print an array of connection names.

Where to put it:

- **Programs started from a terminal:** they need to be started from a shell that has `DBUS_SESSION_BUS_ADDRESS` exported. Running the two lines above in your shell startup file (`~/.zshrc` for the default macOS shell) would start a new bus for every shell, so programs in different terminals wouldn't see each other. If that matters, start the bus once, save the address to a file, and have your startup file export it from there.
- **GUI apps started from Finder, the Dock, or Spotlight:** these don't read shell startup files; they inherit launchd's environment. After starting the bus, copy the address into launchd with `launchctl setenv DBUS_SESSION_BUS_ADDRESS "$DBUS_SESSION_BUS_ADDRESS"`. That lasts until you log out, and only affects apps launched *after* you run it. (This step hasn't been tested with dbus on macOS 27.2.)

Use a `unix:path=` address rather than `launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET`: only `libdbus` understands the `launchd:` address type, while `unix:path=` works with GDBus, sd-bus, pure-language implementations, and everything else.

## Programs Also Need Their Services

Finding the bus is only half the job. Many programs expect other D-Bus *services* to be available on it; for example, anything using the Secret Service API expects something (such as `gnome-keyring-daemon`) to own `org.freedesktop.secrets`. On Linux the desktop session starts these for you. On macOS nothing does, so a program can connect to the bus successfully and still fail because the service it wants isn't there.

There are two ways to get a service running:

- **Start it yourself**, before (or alongside) the program that needs it. Once the service's process is running with `DBUS_SESSION_BUS_ADDRESS` set as above, it connects to the bus and claims its name.
- **Let the bus start it (activation).** If the service ships a `.service` file (like [the one in the Perl example](../examples/perl/net-dbus/activation-test.service)), the session bus can start it automatically the first time someone calls its name. Homebrew's `session.conf` uses `<standard_session_servicedirs />`, which means the XDG data directories (`$XDG_DATA_HOME/dbus-1/services`, defaulting to `~/.local/share/dbus-1/services`, and `dbus-1/services` under each entry of `$XDG_DATA_DIRS`) plus the dbus install's own `share/dbus-1/services`. Homebrew formulae that provide D-Bus services install their `.service` files under `$(brew --prefix)/share/dbus-1/services`; for your own services, `~/.local/share/dbus-1/services` works (confirmed on macOS 27.2 with a bus started as above). After adding a file by hand, restart the bus or have it reload its configuration:

  ```bash
  dbus-send --session --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig
  ```

To see which services the bus can activate, compare `org.freedesktop.DBus.ListActivatableNames` (same `dbus-send` command as above, different method name) with `ListNames`, which shows what's currently running.

## Further Reading

- Upstream notes on the launchd integration: [`README.launchd`](https://gitlab.freedesktop.org/dbus/dbus/-/blob/main/README.launchd)
- The D-Bus specification's section on [server addresses](https://dbus.freedesktop.org/doc/dbus-specification.html#addresses) (including `launchd:` and `autolaunch:`)
- `man dbus-launch` and `man dbus-daemon`
