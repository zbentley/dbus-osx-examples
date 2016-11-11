#!/usr/bin/env perl

use v5.18;
use warnings FATAL => 'all';
use Data::Printer;
use Net::DBus;

# my $address = local $ENV{DBUS_SESSION_BUS_ADDRESS} = "launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET";

my $address = local $ENV{DBUS_SESSION_BUS_ADDRESS} = "unix:path=tst";

say "Using address: $address";

my $bus = Net::DBus->find;
my $service = $bus->get_service("com.zbentley.ipc.gelatin");

my $object = $service->get_object("/ipc/gelatin");

say $object->test_method("foo", "bar");

