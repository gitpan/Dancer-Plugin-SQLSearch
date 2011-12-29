#!/usr/bin/perl -w

use lib 'lib/';
use strict;
use warnings;
use Test::More import => ['!pass'], tests => 9;

{
    use Dancer;
    use Dancer::Plugin::SQLSearch;
    
    set show_errors => 1;
    set session     => 'Simple';
    set logger      => 'console';
    
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
        
        # Verify we get limit and offset correctly
        is $limit, 10, 'Limit has been passed correctly';
        
        if (defined param 'page') {
            # offset should be 20
            is $offset, 20, 'Offset passed correctly when page is requested';
        }
        elsif (defined param 'back') {
            # offset should be 20
            is $offset, 20, 'Offset passed correctly when back to results';
        }
        else {
            # offset should be 0
            is $offset, 0, 'Offset is 0 when a new query is requested';
        }
        
        # Verify we get the data structure correctly
        is_deeply $data,
            [
                name          => { 'ILIKE' => ['%aries%', '%capricornio%'] },
                constellation => { 'ILIKE' => ['%aries%', '%capricornio%'] },
                type          => { 'ILIKE' => ['%aries%', '%capricornio%'] },
            ],
            'Data structure for SQL::Abstract is correct';
        
        return 36, [qw(manzana limon melon ciruela)];
    }
}

use Dancer::Test;

# New query
my $response;
diag 'With new query';
$response = dancer_response 
    GET => '/search', 
    { params => { query => 'aries capricornio' } };

diag 'With new page';
$response = dancer_response 
    GET => '/search', 
    { params => { page => 3 } };

diag 'With back';
$response = dancer_response 
    GET => '/search', 
    { params => { back => 1  } };


__END__

# This is how the query should look
WHERE  name          LIKE '%aries%' OR name          LIKE '%capricornio%'
    OR constellation LIKE '%aries%' OR constellation LIKE '%capricornio%'
    OR type          LIKE '%aries%' OR type          LIKE '%capricornio%'

# This is the data structure for SQL::Abstract
[
    name          => { 'ILIKE' => ['%aries%', '%capricornio%'] },
    constellation => { 'ILIKE' => ['%aries%', '%capricornio%'] },
    type          => { 'ILIKE' => ['%aries%', '%capricornio%'] },
]