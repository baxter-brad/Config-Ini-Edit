#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 8;
use Data::Dumper;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;
use Config::Ini::Edit;

my $ini_data = do{ local $/; <DATA> };

# tests a bug fix where a call to get() was
# autovivifying nodes when checking for a value

Autoviv_get: {

    my $data = $ini_data;

    my $ini1 = Config::Ini::Edit->new( string => $data );
    my $dump1 = Dumper $ini1;

    my $try = $ini1->get(              bad => 'bad' );  # doesn't exist
    $try    = $ini1->get_comments(     bad => 'bad' );
    $try    = $ini1->get_comment(      bad => 'bad' );
    $try    = $ini1->get_section_comments(    'bad' );
    $try    = $ini1->get_section_comment(     'bad' );

    my $dump2 = Dumper $ini1;  # bug was: 'bad' got autovived into $ini1

    is( $dump2, $dump1, 'autoviv in get()' );

}

Autoviv_get_names: {

    my $data = $ini_data;

    my $ini1 = Config::Ini::Edit->new( string => $data );
    my $dump1 = Dumper $ini1;

    my @try = $ini1->get_names( 'bad' );  # doesn't exist

    my $dump2 = Dumper $ini1;

    is( $dump2, $dump1, 'autoviv in get_names()' );

}

Autoviv_get_comments: {

    my $data = $ini_data;

    my $ini1 = Config::Ini::Edit->new( string => $data );
    my $dump1 = Dumper $ini1;

    my @try = $ini1->get_comments( 'bad' => 'bad' );  # doesn't exist

    my $dump2 = Dumper $ini1;

    is( $dump2, $dump1, 'autoviv in get_comments()' );

}

Autoviv_get_comment: {  # wrapper for vattr()

    my $data = $ini_data;

    my $ini1 = Config::Ini::Edit->new( string => $data );
    my $dump1 = Dumper $ini1;

    my @try = $ini1->get_comment( 'bad' => 'bad' );  # doesn't exist

    my $dump2 = Dumper $ini1;

    is( $dump2, $dump1, 'autoviv in get_comment()' );

}

Autoviv_get_section_comments: {

    my $data = $ini_data;

    my $ini1 = Config::Ini::Edit->new( string => $data );
    my $dump1 = Dumper $ini1;

    my @try = $ini1->get_section_comments( 'bad' => 'bad' );  # doesn't exist

    my $dump2 = Dumper $ini1;

    is( $dump2, $dump1, 'autoviv in get_section_comments()' );

}

Autoviv_get_section_comment: {

    my $data = $ini_data;

    my $ini1 = Config::Ini::Edit->new( string => $data );
    my $dump1 = Dumper $ini1;

    my @try = $ini1->get_section_comment( 'bad' => 'bad' );  # doesn't exist

    my $dump2 = Dumper $ini1;

    is( $dump2, $dump1, 'autoviv in get_section_comment()' );

}

Autoviv_vattr_2_parms: {

    my $data = $ini_data;

    my $ini1 = Config::Ini::Edit->new( string => $data );
    my $dump1 = Dumper $ini1;

    my @try = $ini1->vattr( 'bad' => 'bad' );  # doesn't exist

    my $dump2 = Dumper $ini1;

    is( $dump2, $dump1, 'autoviv in vattr(-2 parms-)' );

}

Autoviv_vattr_4_parms: {

    my $data = $ini_data;

    my $ini1 = Config::Ini::Edit->new( string => $data );
    my $dump1 = Dumper $ini1;

    my @try = $ini1->vattr( 'bad' => 'bad', 0, 'comment' );  # doesn't exist

    my $dump2 = Dumper $ini1;

    is( $dump2, $dump1, 'autoviv in vattr(-4 parms-)' );

}

__DATA__
[good]
good = good
