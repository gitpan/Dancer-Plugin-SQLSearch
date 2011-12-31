#!/usr/bin/perl -w

use lib 'lib/';
use strict;
use warnings;
use Data::Dumper;
use Test::More import => ['!pass'];

eval 'use Template';
if ($@) {
    plan skip_all => 'No template toolkit!';
}
else {
    plan tests => 4;
}

{    
    use Dancer;
    use Dancer::Plugin::SQLSearch;
    
    set show_errors => 1;
    set session     => 'Simple';
    set logger      => 'console';
    set template    => 'template_toolkit';
    
    get '/search' => sub {
        my @search_fields = qw( name constellation type ); 
        search (
            query   => param('query'),
            page    => param('page'),
            fields  => \@search_fields,
            execute => \&actual_search, 
        );
        
        return template 'test_template';
    };    

    sub actual_search {
        return 36, [ { 
            name => 'Betelgeuse', constellation => 'Orion', type => 'Star' 
        } ];
    }
}

use Dancer::Test;

# Make sure all keys are available from the template:
my $response = dancer_response 
    GET => '/search', 
    { params => { query => 'orion' } };

is $response->{status}, 200,
    'Status is 200 for new query request';
    
like $response->{content}, qr{Query: orion},
    'Query string is present in template output';

like $response->{content}, qr{Page: 1},
    'Page number is present in template output';

like $response->{content}, qr{Betelgeuse},
    'Results are present in template output';
