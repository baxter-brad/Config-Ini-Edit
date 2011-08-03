#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 12;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );

is( $ini->vattr( '', name => 1, 'quote' ), "'",
    "vattr( quote ) (".__LINE__.")" );

is( $ini->vattr( '', name => 1, 'comment' ), " # comment",
    "vattr( comment ) (".__LINE__.")" );

is( $ini->vattr( '', name => 2, 'quote' ), '"',
    "vattr( quote ) (".__LINE__.")" );

is( $ini->vattr( '', name => 2, 'comment' ), " # 2nd comment",
    "vattr( comment ) (".__LINE__.")" );

is( $ini->vattr( '', name => 3, 'herestyle' ), "<<<<",
    "vattr( herestyle ) (".__LINE__.")" );

is( $ini->vattr( '', name => 4, 'herestyle' ), "<<",
    "vattr( herestyle ) (".__LINE__.")" );

is( $ini->vattr( '', name => 4, 'heretag' ), "EOT",
    "vattr( heretag ) (".__LINE__.")" );

is( $ini->vattr( '', name => 4, 'indented' ), " "x4,
    "vattr( indented ) (".__LINE__.")" );

is( $ini->vattr( '', name => 5, 'quote' ), "'",
    "vattr( quote ) (".__LINE__.")" );

is( $ini->vattr( '', name => 5, 'herestyle' ), "{}",
    "vattr( herestyle ) (".__LINE__.")" );

is( $ini->vattr( '', name => 6, 'herestyle' ), "<<<<",
    "vattr( herestyle ) (".__LINE__.")" );

is( $ini->vattr( '', name => 6, 'json' ), ":json",
    "vattr( json ) (".__LINE__.")" );

__DATA__

name = value
name = 'value' # comment
name = "value" # 2nd comment
name = <<
value
<<
name = <<"EOT:chomp:join:indented" # 3rd comment
    value
            xya
EOT
name = {''
value
}
name = <<:json
{ "a": 1, "b": 2 }
<<
