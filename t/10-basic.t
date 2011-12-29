#!/usr/bin/perl -w

use lib 'lib/';
use strict;
use warnings;
use Test::More import => ['!pass'], tests => 33;

{
    use Dancer;
    use Dancer::Plugin::SQLSearch;
    
    set show_errors => 1;
    set session     => 'Simple';
    set logger      => 'console';
    
    get '/search' => sub {
        my @search_fields = qw( name constellation type ); 
        return search (
            query   => param('query'),
            page    => param('page'),
            back    => param('back'),
            fields  => \@search_fields,
            execute => \&actual_search, 
        );
    };    

    sub actual_search {
        return 36, [qw(manzana limon melon ciruela)];
    }
}

use Dancer::Test;

# Basic tests -- Empy request (empty search page)
route_exists       [ GET => '/search'],
    'Route exists';
my $response = dancer_response 
    GET => '/search';
is $response->{status}, 200,
    'Status is 200 for empty request';
    
foreach my $field (qw{query count results page last_page prev_page next_page}) {
    ok      exists  $response->{content}{$field} 
        && !defined $response->{content}{$field},
        "Search returned empty $field for empty request";
}

# Basic interface -- New query
$response = dancer_response 
    GET => '/search', 
    { params => { query => 'aries' } };

is $response->{status}, 200,
    'Status is 200 for new query request';
is $response->{content}{query}, 'aries',
    'Search query is included';
is $response->{content}{count}, 36,
    'Number of hits is included';
is_deeply $response->{content}{results},
    [qw(manzana limon melon ciruela)],
    'Search results are returned';
is $response->{content}{page},
    1,
    'Page is 1';
is $response->{content}{last_page},
    4,
    'Last page is 1';
ok exists $response->{content}{prev_page},
    'Previous page link exists';
is $response->{content}{next_page},
    2,
    'Next page is 2';


# Basic interface -- Other page
$response = dancer_response
    GET => '/search', 
    { params => { page => 3 } };
    
is $response->{status}, 200,
    'Status is 200 for other page request';
is $response->{content}{query}, 'aries',
    'Search query is included';
is $response->{content}{count}, 36,
    'Number of hits is included';
is_deeply $response->{content}{results},
    [qw(manzana limon melon ciruela)],
    'Search results are returned';
is $response->{content}{page},
    3,
    'Current page is 3';
is $response->{content}{last_page},
    4,
    'Last page is 4';
is $response->{content}{prev_page},
    2,
    'Previous page is 2';
is $response->{content}{next_page},
    4,
    'Next page is 4';


# Basic interface -- Back to search results
$response = dancer_response
    GET => '/search', 
    { params => { back => 1 } };
    
is $response->{status}, 200,
    'Status is 200 for back to search results';
is $response->{content}{query}, 'aries',
    'Search query is included';
is $response->{content}{count}, 36,
    'Number of hits is included';
is_deeply $response->{content}{results},
    [qw(manzana limon melon ciruela)],
    'Search results are returned';
is $response->{content}{page},
    3,
    'Page is 3';
is $response->{content}{last_page},
    4,
    'Last page is 4';
is $response->{content}{prev_page},
    2,
    'Previous page is 2';
is $response->{content}{next_page},
    4,
    'Next page is 4';
