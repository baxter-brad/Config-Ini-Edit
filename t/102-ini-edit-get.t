#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 7;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );

is( $ini->get( section1 => 'name1.1' ), 'value1.1',
    'get( section, name )' );

is( $ini->get( section1 => 'name1.1', 0 ), 'value1.1',
    'get( section, name, 0 )' );

is( $ini->get( section1 => 'name1.2', 1 ), 'value1.2b',
    'get( section, name, i )' );

my @values = $ini->get( section2 => 'name2.1' );
is( "@values", "value2.1\n",
    'get( section, name ) (heredoc)' );

@values = $ini->get( section2 => 'name2.2' );
is( "@values", "value2.2\nvalue2.2",
    'get( section, name ) (heredoc :chomp)' );

@values = $ini->get( section2 => 'name2.3' );
is( "@values", "value2.3value2.3\n",
    'get( section, name ) (heredoc :join)' );

@values = $ini->get( section2 => 'name2.4' );
is( "@values", "value2.4 value2.4",
    'get( section, name ) (heredoc :parse)' );

__DATA__
# Section 1

[section1]

# Name 1.1
name1.1 = value1.1

# Name 1.2a
name1.2 = value1.2a
# Name 1.2b
name1.2 = value1.2b

# Section 2

[section2]

# Name 2.1

name2.1 = {
value2.1
}
name2.2 = <<:chomp
value2.2
value2.2
<<
name2.3 = {here :join
value2.3
value2.3
}here
name2.4 = <<here :parse(\n)
value2.4
value2.4
<<here
