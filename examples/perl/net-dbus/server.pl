#!/usr/bin/env perl


use strict;
use warnings FATAL => 'all';
use feature "say";

# We have two packages in this file, one creating the requied DBus
# API and one running the server script ("main"). As a result, the
# package declaration is a bit further down than usual. In production,
# these would likely be separate .pm/.pl files.
package ServedObject;

use Net::DBus;
# Packages represent dbus object sets via inheritance (weird API design
# choice on the part of the module authors, but eh).
use parent qw( Net::DBus::Object );

# Packages declare service exports in several ways. The shortest is the
# most counterintuitive: via an import argument to the Exporter package,
# but only if it's issued after the DBus::Object inheritance is set up.
use Net::DBus::Exporter qw( com.website.service.identifier );

sub new {
    my ( $class, $service ) = @_;
    return $class->SUPER::new($service, "/object/path");
}

# Think of dbus_method calls like a Python decorator or Java annotation.
# They work the same way. Perl subroutine attributes could possibly be
# used as well, but I don't think anyone has written that module yet.
dbus_method("test_method", ["string", "string"], ["string"]);
sub test_method {
    my ( $self, $arg1, $arg2 ) = @_;
    say "WHOA";
    return "$arg1 :: $arg2";
}

1;

# For actually running the server script:
package main;
use Net::DBus;
use Net::DBus::Reactor;

# Switch the below two lines (uncomment) if using launchd:
# my $address = local $ENV{DBUS_SESSION_BUS_ADDRESS} = "launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET";
my $address = local $ENV{DBUS_SESSION_BUS_ADDRESS} = "unix:path=tst";
say "Using address: $address";

my $bus = Net::DBus->find;
my $service = $bus->export_service("com.website.service.identifier");
# Think of the server-invoking convention as a "backwards mount". What you want
# to do is "mount" an object's functionality on a service instance. To do
# that, you instantiate the object with an argument of the service you want
# to provide it.
my $object = ServedObject->new($service);

sleep 10;

# The major drawback of Net::DBus is that for servers it requires its own
# event loop. There are ways around that in CPAN, but none of them are great.
Net::DBus::Reactor->main->run;

1;