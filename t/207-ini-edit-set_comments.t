#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 4;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );

my $result = <<'__';
[section]
# one fish
name = value
# two fish
name = value
# red fish
name = value
__

$ini->set_comments( section => 'name', 0, 'one fish' );
$ini->set_comments( section => 'name', 1, 'two fish' );
$ini->set_comments( section => 'name', 2, 'red fish' );
is( $ini->as_string(), $result, 'set_comments (no #...\n)' );

$ini->set_comments( section => 'name', 0, '# one fish' );
$ini->set_comments( section => 'name', 1, '# two fish' );
$ini->set_comments( section => 'name', 2, '# red fish' );
is( $ini->as_string(), $result, 'set_comments (no ...\n)' );

$ini->set_comments( section => 'name', 0, "one fish\n" );
$ini->set_comments( section => 'name', 1, "two fish\n" );
$ini->set_comments( section => 'name', 2, "red fish\n" );
is( $ini->as_string(), $result, 'set_comments (with ...\n)' );

$ini->set_comments( section => 'name', 0, "# one fish\n" );
$ini->set_comments( section => 'name', 1, "# two fish\n" );
$ini->set_comments( section => 'name', 2, "# red fish\n" );
is( $ini->as_string(), $result, 'set_comments (with #...\n)' );

__DATA__
[section]
name = value
name = value
name = value
