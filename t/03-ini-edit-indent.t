#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 1;
use Config::Ini::Edit;

my $ini_data = do{ local $/; <DATA> };

Indent: {

    my $data = $ini_data;
    my $ini = Config::Ini::Edit->new( string => $ini_data );
    is( $ini->get( section1 => 'name1.1' ), 'Thisisatest',
        "indented" );
}

__DATA__
# Section 1

[section1]

# Name 1.1
name1.1 = <<:indented:join:chomp
    This
    is
    a
    test
<<

