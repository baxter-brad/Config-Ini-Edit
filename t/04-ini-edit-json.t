#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 2;
use JSON;
use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );
my $obj = $ini->get( section => 'name' );
my $jobj = JSON::->new->pretty->canonical;
my $string = $jobj->encode( $obj );
is( $string, <<'__', 'json ('.__LINE__.')' );
{
   "a" : 1,
   "b" : 2,
   "c" : 3
}
__
    is( $ini->as_string(), <<'__', 'json ('.__LINE__.')' );
[section]
name = <<:json
{
   "a" : 1,
   "b" : 2,
   "c" : 3
}
<<
__

__DATA__
[section]
name = <<:json
{"a":1,"b":2,"c":3}
<<
