#!/usr/bin/env perl

use v5.18;
use warnings FATAL => 'all';

package ServedObject;
use Net::DBus;
use parent qw(Net::DBus::Object);


use Net::DBus::Exporter qw(com.zbentley.ipc.gelatin);

sub new {
    my ( $class, $service ) = @_;
    return $class->SUPER::new($service, "/ipc/gelatin");
}

dbus_method("test_method", ["string", "string"], ["string"]);
sub test_method {
    my ( $self, $arg1, $arg2 ) = @_;
    say "WHOA";
    return "$arg1 :: $arg2";
}

1;




package main;
use Data::Printer;
use Net::DBus;
use Net::DBus::Reactor;

#my $address = local $ENV{DBUS_SESSION_BUS_ADDRESS} = "launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET";

my $address = local $ENV{DBUS_SESSION_BUS_ADDRESS} = "unix:path=tst";say "Using address: $address";

my $bus = Net::DBus->find;
my $service = $bus->export_service("com.zbentley.ipc.gelatin");
my $object = ServedObject->new($service);
sleep 10;
Net::DBus::Reactor->main->run;

1;