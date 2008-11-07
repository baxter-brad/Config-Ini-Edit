#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 4;
use Config::Ini::Edit;

my $ini_data = do{ local $/; <DATA> };

Get_comments: {

    my $data = $ini_data;
    my $ini = Config::Ini::Edit->new( string => $ini_data );
    my @comments = $ini->get_comments( section => 'name' );
    is( join('',@comments), "#1\n", 'get_comments ('.__LINE__.')' );
}

Get_comment: {

    my $data = $ini_data;
    my $ini = Config::Ini::Edit->new( string => $ini_data );
    my $comment = $ini->get_comment( section => 'name' );
    is( $comment, " # after 1", 'get_comment ('.__LINE__.')' );

    $comment = $ini->get_comment( section => 'name', 0 );
    is( $comment, " # after 1", 'get_comment ('.__LINE__.')' );

    $comment = $ini->get_comment( section => 'name', 1 );
    is( $comment, " # after 2", 'get_comment ('.__LINE__.')' );

}


__DATA__
#begin
[section] #after
#1
name = '1' # after 1
#2
name = "2" # after 2
#3
name = 3
#end
