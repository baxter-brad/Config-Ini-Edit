#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 12;
use Config::Ini::Edit;

my $ini_data = do{ local $/; <DATA> };

Null_section: {

    my $data = $ini_data;
    my $ini = Config::Ini::Edit->new( string => $ini_data );

    # get(?)
    is( $ini->get( 'a' ), "1 alpha", "get(), null section" );
    is( $ini->get( 'b' ), 'baker',   "get(), null section" );
    is( $ini->get( 'c' ), 'charlie', "get(), null section" );
    is( $ini->get( 'd' ), 'dog',     "get(), null section" );
    is( $ini->get( 'e' ), 'echo',    "get(), null section" );

    # get('',?)
    is( $ini->get( '', 'a' ), '1 alpha', "get(), null section" );
    is( $ini->get( '', 'b' ), 'baker',   "get(), null section" );
    is( $ini->get( '', 'c' ), 'charlie', "get(), null section" );
    is( $ini->get( '', 'd' ), 'dog',     "get(), null section" );
    is( $ini->get( '', 'e' ), 'echo',    "get(), null section" );

    # get_names()
    my @explicit = $ini->get_names( '' );
    my @implicit = $ini->get_names();
    is( "@explicit", 'a b c d e', "get_names(), null section" );
    is( "@explicit", 'a b c d e', "get_names(), null section" );
}

__DATA__
# "null section"
a
a = alpha
b = baker
; "still null section"
c : charlie
d : dog
[section1]
c = charlie
d = dog
[] # null section again
e = echo

