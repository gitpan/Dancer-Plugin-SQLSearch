#!/usr/bin/perl -w

use lib 'lib/';
use strict;
use warnings;
use Test::More import => ['!pass'], tests => 3;

{
    use Dancer;
    use Dancer::Plugin::SQLSearch;
    
    # Test that params can be taken from config file
    set plugins =>  { 
        SQLSearch => { 
            fields           => [ qw(name constellation type) ], 
            results_per_page => 15, 
            search_operator  => 'ILIKE' 
        }
    };
    
    
    get '/search' => sub {
        return search (
            query   => param('query'),
            page    => param('page'),
            execute => \&actual_search, 
        );
    };    

    sub actual_search {
        my ($where, $offset, $limit) = @_;

        is( $limit, 15,
            'results_per_page loaded correctly from config file');

        is_deeply( $where, 
            [
                name          => { 'ILIKE' => ['%orion%'] },
                constellation => { 'ILIKE' => ['%orion%'] },
                type          => { 'ILIKE' => ['%orion%'] },
            ],
            'Search fields and search operator loaded correctly from config file');
        
        return 36, [qw(manzana limon melon ciruela)];
    }
}

use Dancer::Test;

# First of all, if fields are not specified we will die...
my $response = dancer_response 
        GET => '/search',
        { params => { query => 'orion' } };

is $response->{status}, 200,
    'Status is 200, so everything ran smoothly';
