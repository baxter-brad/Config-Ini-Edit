#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 10;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );

is( defined $ini->file(), '', 'file() ('.__LINE__.')' );
is( $ini->file( 'acme.ini' ), 'acme.ini', 'file() ('.__LINE__.')' );
is( $ini->file(), 'acme.ini', 'file() ('.__LINE__.')' );
is( $ini->keep_comments(), 1, 'keep_comments() ('.__LINE__.')' );
is( $ini->keep_comments(0), 0, 'keep_comments() ('.__LINE__.')' );
is( $ini->keep_comments(), 0, 'keep_comments() ('.__LINE__.')' );
is( $ini->heredoc_style(), '<<', 'heredoc_style() ('.__LINE__.')' );
is( $ini->heredoc_style('{}'), '{}', 'heredoc_style() ('.__LINE__.')' );
is( $ini->heredoc_style(), '{}', 'heredoc_style() ('.__LINE__.')' );
eval{ $ini->you_dont_know_me(1); };
ok( $@ =~ /^Undefined: you_dont_know_me()/, 'undefined sub()' );

__DATA__
[section]
name = value
