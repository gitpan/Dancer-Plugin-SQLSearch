#!/usr/bin/perl -w

use lib 'lib/';
use strict;
use warnings;
use Test::More import => ['!pass'], tests => 2;
use Data::Dumper;

{
    use Dancer;
    use Dancer::Plugin::SQLSearch;
    
    set show_errors => 1;
    set session     => 'Simple';
    set logger      => 'capture';
    
    get '/search' => sub {
        my @search_fields = qw( name constellation type ); 
        return search (
            query           => param('query'),
            page            => param('page'),
            back            => param('back'),
            fields          => \@search_fields,
            execute         => \&actual_search, 
            search_operator => 'ILIKE',
        );
    };    

    sub actual_search {
        # These are the tests to run against the search routine input
        my ($data, $offset, $limit) = @_;
        
        is_deeply $data,
            [
                name          => { 'ILIKE' => ['%aries%', '%capricornio%'] },
                constellation => { 'ILIKE' => ['%aries%', '%capricornio%'] },
                type          => { 'ILIKE' => ['%aries%', '%capricornio%'] },
            ],
            'Query received fine in search routine';
        
        die 'This routine should die';
        
        return 36, [qw(manzana limon melon ciruela)];
    }
}

use Dancer::Test;

# New query
my $response;
$response = dancer_response 
    GET => '/search', 
    { params => { query => 'aries capricornio' } };

my $log = read_logs;
like $log->[0]{message}, 
    qr/Your search routine failed/,
    'Actual search routine exception is caught by plugin';

