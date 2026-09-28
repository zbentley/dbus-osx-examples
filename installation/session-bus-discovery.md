# How Programs Find the Session Bus on macOS

On Linux, programs usually find the session bus through the `DBUS_SESSION_BUS_ADDRESS` environment variable, a well-known socket at `$XDG_RUNTIME_DIR/bus`, or by running `dbus-launch --autolaunch`. None of these apply by default on macOS. This document explains what happens instead, why `dbus-launch --autolaunch` fails, and how to point a program that can't find the bus at the right place.

If you haven't set up a session bus yet, do that first; see [the installation guide](README.md).

## How the launchd Integration Works

The Homebrew session bus is started by `launchd`, not by your shell or login session. The pieces fit together like this:

1. **launchd owns the socket.** The `org.freedesktop.dbus-session.plist` launch agent has a `Sockets` entry with a `SecureSocketWithKey` of `DBUS_LAUNCHD_SESSION_BUS_SOCKET`. When the agent is loaded, launchd creates a Unix socket at a random path (something like `/private/tmp/com.apple.launchd.AbCdEf1234/unix_domain_listener`) and publishes that path in *launchd's* environment under the name `DBUS_LAUNCHD_SESSION_BUS_SOCKET`.
2. **The daemon is started on demand.** `dbus-daemon` is not necessarily running just because the agent is loaded. launchd starts it when the first client connects to the socket. So `ps -ef | grep [d]bus` can come up empty on a perfectly working setup; the check that matters is whether the socket exists (below).
3. **The daemon checks in with launchd.** Homebrew's `session.conf` listens on `launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET`. That tells `dbus-daemon` to ask launchd for the already-open socket instead of creating its own. This is why starting `dbus-daemon --session` by hand fails with `Check-in failed: No such process`: the daemon wasn't started by launchd, so there is nothing to check in with. (See "Manually Launching the Session Bus" in the [installation guide](README.md) for how to run it without launchd.)
4. **Clients ask launchd for the socket path.** When `DBUS_SESSION_BUS_ADDRESS` is not set, `libdbus` on macOS uses the default address `launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET`, looks the path up in launchd's environment, and connects to it as `unix:path=<that path>`.

The important detail in steps 1 and 4 is that `DBUS_LAUNCHD_SESSION_BUS_SOCKET` lives in launchd's environment, not your shell's. It usually won't show up in `env`. To see it, ask launchd:

```bash
launchctl getenv DBUS_LAUNCHD_SESSION_BUS_SOCKET
```

If that prints a path, the session bus agent is loaded and clients that understand launchd will find it. If it prints nothing, the agent isn't loaded; start it with `brew services start dbus` or the `launchctl` steps in the [installation guide](README.md).

The socket path changes every time the agent is loaded (typically once per login), so never hardcode it anywhere.

## Why `dbus-launch --autolaunch` Fails

"Autolaunch" is a mechanism for finding (or starting) a session bus that belongs to an X11 display. `dbus-launch --autolaunch` records the bus address on the X server, so every program on the same display shares one bus. It needs `dbus-launch` to be built with X11 support.

Homebrew's `dbus` is built without X11, and a normal macOS desktop has no X display anyway. So when a program runs `dbus-launch --autolaunch=...`, it fails, typically with:

```
Autolaunch requested, but X11 support not compiled in.
Cannot continue.
```

Programs hit this when they don't know about launchd. The usual culprit is GLib's GDBus (used by GTK/GNOME programs such as Fractal, `gnome-keyring`, `gsettings` and friends). When `DBUS_SESSION_BUS_ADDRESS` is unset, GDBus falls back to autolaunching via `dbus-launch`. Newer GLib releases ask launchd for `DBUS_LAUNCHD_SESSION_BUS_SOCKET` on macOS first, so upgrading GLib (`brew upgrade glib`) may be enough. For programs built against an older GLib, or that bundle their own D-Bus client, use the fix below.

This is not a problem with the bus. The bus is running (or ready to start on demand); the program just doesn't know how to find it.

## Fix: Tell the Program Where the Bus Is

Every D-Bus client library honors `DBUS_SESSION_BUS_ADDRESS`, and if it's set they skip autolaunch entirely. Set it from launchd's value:

```bash
export DBUS_SESSION_BUS_ADDRESS="unix:path=$(launchctl getenv DBUS_LAUNCHD_SESSION_BUS_SOCKET)"
```

Use the `unix:path=` form rather than `launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET`: only `libdbus` understands the `launchd:` address type, while `unix:path=` works with GDBus, sd-bus, pure-language implementations, and everything else.

Where to put it:

- **Programs started from a terminal:** add the `export` line to your shell startup file (`~/.zshrc` for the default macOS shell, `~/.bash_profile` for bash). Because the value is looked up when each shell starts, it stays correct across logins.
- **GUI apps started from Finder, the Dock, or Spotlight:** these don't read shell startup files. They inherit launchd's environment, so set the variable there:

  ```bash
  launchctl setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$(launchctl getenv DBUS_LAUNCHD_SESSION_BUS_SOCKET)"
  ```

  This lasts until you log out, and only affects apps launched *after* you run it. To make it permanent, run that command at login from a small launch agent of your own, or from a login script.

To check that the address works:

```bash
dbus-send --session --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListNames
```

That should print an array of connection names. If it hangs or errors, go back to `launchctl getenv DBUS_LAUNCHD_SESSION_BUS_SOCKET` and make sure it prints a path.

## Programs Also Need Their Services

Finding the bus is only half the job. Many programs expect other D-Bus *services* to be available on it; for example, anything using the Secret Service API expects something (such as `gnome-keyring-daemon`) to own `org.freedesktop.secrets`. On Linux the desktop session starts these for you. On macOS nothing does, so a program can connect to the bus successfully and still fail because the service it wants isn't there.

There are two ways to get a service running:

- **Start it yourself**, before (or alongside) the program that needs it. Once the service's process is running with `DBUS_SESSION_BUS_ADDRESS` set as above, it connects to the bus and claims its name.
- **Let the bus start it (activation).** If the service ships a `.service` file (like [the one in the Perl example](../examples/perl/net-dbus/activation-test.service)), the session bus can start it automatically the first time someone calls its name. The Homebrew session bus looks for these files in `$(brew --prefix)/share/dbus-1/services` and `~/.local/share/dbus-1/services`. Homebrew formulae that provide D-Bus services usually install their `.service` files into the first location already. After adding a file by hand, restart the bus or have it reload its configuration:

  ```bash
  dbus-send --session --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig
  ```

To see which services the bus can activate, compare `org.freedesktop.DBus.ListActivatableNames` (same `dbus-send` command as above, different method name) with `ListNames`, which shows what's currently running.

## Further Reading

- Upstream notes on the launchd integration: [`README.launchd`](https://gitlab.freedesktop.org/dbus/dbus/-/blob/main/README.launchd)
- The D-Bus specification's section on [server addresses](https://dbus.freedesktop.org/doc/dbus-specification.html#addresses) (including `launchd:` and `autolaunch:`)
- `man dbus-launch` and `man dbus-daemon`
