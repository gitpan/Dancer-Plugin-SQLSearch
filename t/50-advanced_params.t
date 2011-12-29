#!/usr/bin/perl -w

use lib 'lib/';
use strict;
use warnings;
use Test::More import => ['!pass'], tests => 1;

{
    use Dancer;
    use Dancer::Plugin::SQLSearch;
    
    my %advanced = (
        field1 => 1,
        field2 => 2
    );
    
    get '/search' => sub {
        my @search_fields = qw( name constellation type ); 
        return search (
            query           => param('query'),
            advanced        => \%advanced,
            fields          => \@search_fields,
            execute         => \&actual_search, 
            search_operator => 'ILIKE',
        );
    };    

    sub actual_search {
        # These are the tests to run against the search routine input
        my ($data, $offset, $limit) = @_;
        
        # Verify we get the data structure correctly
        is_deeply $data,
            [
                -and => [
                    {
                        field1 => 1,
                        field2 => 2,
                    },
                    [
                        name          => { 'ILIKE' => ['%test%', '%string%'] },
                        constellation => { 'ILIKE' => ['%test%', '%string%'] },
                        type          => { 'ILIKE' => ['%test%', '%string%'] },
                    ]
                ]
            ],
            'Data structure with advanced search params is correct';
        
        return 36, [qw(manzana limon melon ciruela)];
    }
}

use Dancer::Test;

my $response;
$response = dancer_response 
    GET => '/search', 
    { 
        params => { 
            query   => 'test string',
        }
    };
