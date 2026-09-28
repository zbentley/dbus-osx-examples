#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';
use feature "say";

use Net::DBus;

# By default, talk to the bus started from this directory's session.conf.
# To use the launchd-managed session bus instead, run with
# DBUS_SESSION_BUS_ADDRESS=launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET
my $address = local $ENV{DBUS_SESSION_BUS_ADDRESS} =
    $ENV{DBUS_SESSION_BUS_ADDRESS} // "unix:path=/tmp/dbus-perl-example.sock";
say "Using address: $address";

my $bus = Net::DBus->find;
my $service = $bus->get_service("com.website.service.identifier");

my $object = $service->get_object("/object/path");

say $object->test_method("foo", "bar");

