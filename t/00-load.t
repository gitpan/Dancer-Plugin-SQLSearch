#! /usr/bin/perl -w

use Test::More tests => 1;
use lib 'lib/';

BEGIN {
    use_ok( 'Dancer::Plugin::SQLSearch' ) || print "Bail out!
";
}

diag( "Testing Dancer::Plugin::SQLSearch $Dancer::Plugin::SQLSearch::VERSION, Perl $], $^X" );
