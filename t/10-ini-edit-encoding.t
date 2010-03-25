#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 8;
use Encode;

BEGIN { use_ok('Config::Ini::Edit') };

my $utf8_data = <<_end_;
[section]
inv_excl   = U+00A1  Â¡  c2 a1  INVERTED EXCLAMATION MARK 
cent_sign  = U+00A2  Â¢  c2 a2  CENT SIGN 
pound_sign = U+00A3  Â£  c2 a3  POUND SIGN 
inv_quest  = U+00BF  Â¿  c2 bf  INVERTED QUESTION MARK 
sm_u_grave = U+00F9  \303\271  c3 b9  LATIN SMALL LETTER U WITH GRAVE
_end_

my $latin1_data = <<_end_;
[section]
inv_excl   = U+00A1  ¡  c2 a1  INVERTED EXCLAMATION MARK 
cent_sign  = U+00A2  ¢  c2 a2  CENT SIGN 
pound_sign = U+00A3  £  c2 a3  POUND SIGN 
inv_quest  = U+00BF  ¿  c2 bf  INVERTED QUESTION MARK 
sm_u_grave = U+00F9  ù  c3 b9  LATIN SMALL LETTER U WITH GRAVE
_end_

unlike( $utf8_data,   qr/^[[:print:]]+$/, "isn't recognized printable" );
unlike( $latin1_data, qr/^[[:print:]]+$/, "isn't recognized printable" );

my $from_utf8 = Encode::decode( 'UTF-8', $utf8_data );
like( $from_utf8, qr/^[[:print:]]+$/, 'is recognized printable'  );

my $from_latin1 = Encode::decode( 'ISO-8859-1', $latin1_data );
like( $from_latin1, qr/^[[:print:]]+$/, 'is recognized printable'  );

is( $from_utf8, $from_latin1, 'internal representations equal' );

# default $Config::Ini::Edit::encoding = '';
my $ini_no_encoding = Config::Ini::Edit->new( string => $latin1_data );

$Config::Ini::Edit::encoding = 'utf8';
my $ini_from_utf8 = Config::Ini::Edit->new( string => $utf8_data );

$Config::Ini::Edit::encoding = 'iso-8859-1';
my $ini_from_latin1 = Config::Ini::Edit->new( string => $latin1_data );

is( $ini_from_latin1->as_string(), $ini_no_encoding->as_string(), "non-encoded as_string equal to latin1" );
is( $ini_from_utf8->as_string(),   $ini_from_latin1->as_string(), "encoded as_string's equal" );


__END__
