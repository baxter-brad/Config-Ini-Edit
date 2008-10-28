#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 4;
use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );
is( $ini->get( 'a' ), "1 alpha", "get(), null section" );
is( $ini->get( 'b' ), 'baker',   "get(), null section" );
is( $ini->get( 'c' ), 'charlie', "get(), null section" );
is( $ini->get( 'd' ), 'dog',     "get(), null section" );

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

