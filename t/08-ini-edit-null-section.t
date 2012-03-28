#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 14;
use Config::Ini::Edit;

#---------------------------------------------------------------------
# general tests for null section values

GROUP1: {

    my $ini_data = <<_end_;
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
_end_

    my $expect = <<_end_; # almost the same as $ini_data
# "null section"
a
a = alpha
b = baker
; "still null section"
c : charlie
d : dog
e = echo

[section1]
c = charlie
d = dog
_end_

    my $ini = Config::Ini::Edit->new( string => $ini_data );
    is( $ini->as_string(), $expect, "as_string(), null sections" );

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
    is( "@implicit", 'a b c d e', "get_names(), null section" );
   
}

#---------------------------------------------------------------------
# specifically test that as_string() outputs null sections after a
# non-null section

GROUP2: {
    my $ini_data = <<_end_;
[section]
c = charlie
d = dog

[]
a
a = alpha
b = baker
c : charlie
d : dog
e = echo
_end_

    my $ini = Config::Ini::Edit->new( string => $ini_data );
    is( $ini->as_string(), $ini_data, "as_string(), null sections" );

}
