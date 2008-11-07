#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 4;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );

my $result = <<'__';
[section] # fishes
name = 'value' # one fish
name = 'value' # two fish
name = 'value' # red fish
__

$ini->set_section_comment( section => 'fishes' );

$ini->set_comment( section => 'name', 0, 'one fish' );
$ini->set_comment( section => 'name', 1, 'two fish' );
$ini->set_comment( section => 'name', 2, 'red fish' );
is( $ini->as_string(), $result, 'set_comment (no #...\n)' );

$ini->set_section_comment( section => ' # fishes' );

$ini->set_comment( section => 'name', 0, ' # one fish' );
$ini->set_comment( section => 'name', 1, ' # two fish' );
$ini->set_comment( section => 'name', 2, ' # red fish' );
is( $ini->as_string(), $result, 'set_comment (no ...\n)' );

$ini->set_section_comment( section => "fishes\n" );

$ini->set_comment( section => 'name', 0, "one fish\n" );
$ini->set_comment( section => 'name', 1, "two fish\n" );
$ini->set_comment( section => 'name', 2, "red fish\n" );
is( $ini->as_string(), $result, 'set_comment (with ...\n)' );

$ini->set_section_comment( section => " # fishes\n" );

$ini->set_comment( section => 'name', 0, " # one fish\n" );
$ini->set_comment( section => 'name', 1, " # two fish\n" );
$ini->set_comment( section => 'name', 2, " # red fish\n" );
is( $ini->as_string(), $result, 'set_comment (with #...\n)' );

__DATA__
[section]
name = value
name = value
name = value
