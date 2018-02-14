#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';
use feature "say";

use Net::DBus;

# Switch the below two lines (uncomment) if using launchd:
# my $address = local $ENV{DBUS_SESSION_BUS_ADDRESS} = "launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET";
my $address = local $ENV{DBUS_SESSION_BUS_ADDRESS} = "unix:path=tst";
say "Using address: $address";

my $bus = Net::DBus->find;
my $service = $bus->get_service("com.website.service.identifier");

my $object = $service->get_object("/object/path");

say $object->test_method("foo", "bar");

