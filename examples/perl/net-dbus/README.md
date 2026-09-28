# Net::DBus example

A skeleton client and server using the [`Net::DBus`](https://metacpan.org/pod/Net::DBus) Perl module. The server exports one object at `/object/path` under the name `com.website.service.identifier`, with a `test_method` that takes two strings and returns them joined.

## Running it

1. Install D-Bus (see [the installation guide](../../../installation/README.md)) and the Perl module (`cpanm Net::DBus`).
2. In this directory, start a private session bus using the included config. It listens on `/tmp/dbus-perl-example.sock`:

	```bash
	dbus-daemon --nofork --config-file=session.conf
	```

3. In a second terminal in this directory, start the server with `perl server.pl`.
4. In a third terminal, run `perl client.pl`. It should print `foo :: bar`.

Both scripts connect to `/tmp/dbus-perl-example.sock` unless `DBUS_SESSION_BUS_ADDRESS` is already set. To use the `launchd`-managed session bus instead, run them with `DBUS_SESSION_BUS_ADDRESS=launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET`.

## Bus activation

`session.conf` also loads `.service` files from this directory, so the bus can start the server on demand. To try it, edit the `Exec=` line in `activation-test.service` to the absolute path of `server.pl`, restart the bus, and run `client.pl` without starting the server first.

`session.conf` includes local configuration from the Apple Silicon Homebrew prefix (`/opt/homebrew`). On an Intel Mac, change those paths to `/usr/local`.
