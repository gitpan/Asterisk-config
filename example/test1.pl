#!/usr/bin/perl
use Data::Dumper;
require "../config.pm";

my $rc = new Asterisk::config(file=>'sip.conf',keep_resource_array=>0);
if ($rc) {
	print "true";
}
print Dumper $rc;
