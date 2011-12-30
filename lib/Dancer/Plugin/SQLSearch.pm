package Dancer::Plugin::SQLSearch;
use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Exception qw(try catch);

use Carp;
use warnings;
use strict;

our $VERSION = '0.02';

# The search method can be called in four ways:
# 1) To get a blank search page
# 2) With a new query
# 3) With a new page
# 4) To get back to the previous search results

register search => sub {
    # Default settings
    my %args = (
        search_operator  => 'LIKE', 
        results_per_page => 10,
    );

    # Config settings
    my $conf = plugin_setting();
    $args{fields} = $conf->{fields} 
        if defined $conf->{fields};
    $args{search_operator} = $conf->{search_operator} 
        if defined $conf->{search_operator};
    $args{results_per_page} = $conf->{results_per_page} 
        if defined $conf->{results_per_page};
    
    # Inline settings
    %args = (%args, @_);
    
    # Make sure mandatory arguments are set
    croak 'Your search routine is not a code reference' 
        unless defined $args{execute} && ref $args{execute} eq 'CODE';
    croak 'Your search fields are not in an array reference'
        unless defined $args{fields}  && ref $args{fields}  eq 'ARRAY';
    
    # Build response    
    my %search = (
        query      => undef,
        page       => undef,
        page       => undef,
        first_page => undef,
        prev_page  => undef,
        next_page  => undef,
        last_page  => undef,
        count      => undef,
        results    => undef,
    );
    
    my $where;
    my $offset;
    my $limit = $args{results_per_page};
    my $prev_search = session('_sqlsearch_plugin');
    
    # Is there a new query?
    if ($args{query}) {
        $search{query}  = $args{query};
        $search{page}   = 1;
        $offset         = 0;
        $where          = _parse(
            $args{search_operator}, $search{query}, $args{fields}
        );
        if ((ref $args{advanced} eq 'HASH'  && %{ $args{advanced} } )
        || (ref $args{advanced} eq 'ARRAY' && @{ $args{advanced} } ) ) {
            $where = [ -and => [ $args{advanced}, $where ] ];
        }
    }
    # No query but advanced params?
    elsif ((ref $args{advanced} eq 'HASH'  && %{ $args{advanced} } )
        || (ref $args{advanced} eq 'ARRAY' && @{ $args{advanced} } )
    ) {
        $search{query}  = undef;
        $search{page}   = 1;
        $where          = $args{advanced};
        $offset         = 0;
    }
    # You want other page?
    elsif ($args{page}) {
        $search{query}  = $prev_search->{query};
        $search{page}   = $args{page},
        $where          = $prev_search->{where};
        $offset         = $args{results_per_page} * ($search{page} - 1);
    }
    # Or perhaps back to previous results?
    elsif ($args{back}) {
        $search{query}  = $prev_search->{query};
        $search{page}   = $prev_search->{page},
        $where          = $prev_search->{where};
        $offset         = $args{results_per_page} * ($search{page} - 1);
    }
    # ... or may be not?
    else {
        $search{query}   = undef;
        $search{page}    = undef;
        $search{count}   = undef;
        $search{results} = undef;
    }
        
    # We are ready to fetch the search results    
    if (defined $where) {
        ###### IMPORTANT: This part is broken. I am not catching exceptions!!
        ###### This means that the user receives mysterious failure messages
        ###### instead of the real thing (which I cannot see!)
        try {
            ($search{count}, $search{results}) = 
                $args{execute}->($where, $offset, $limit);
        };
        catch {
            croak "Search subroutine failed during execution: $_";
        }
        
        ###### Remove when fixed exceptions are fixed:
        croak "Your search routine failed to return data"
            unless defined $search{count};
    }
    
    # Now we must update pagination links    
    if (defined $search{page}) {
        $search{first_page} = 1;
        $search{prev_page}  = $search{page} > 1 ? $search{page} - 1 : undef;
        $search{last_page}  = int($search{count} / $args{results_per_page}) + 1;
        $search{next_page}  = $search{last_page} > $search{page} ? 
            $search{page} + 1 : undef;
    }
    
    # Save search in session object
    session '_sqlsearch_plugin' => {
        query     => $search{query},
        page      => $search{page},
        where     => $where,
    };
    
    # Share info with templates
    hook before_template => sub {
        my $tokens        = shift;
        $tokens->{search} = \%search;
    };
    
    # OK, we're done
    return \%search;    
};

register_plugin;

##################################################################
# _parse and _parse_chunks were shamelessly copied from          #
# Text::SQLSearch::SQL by Chisel Wright (with minor adaptations) #
##################################################################
sub _parse {
    my ($search_type, $search_term, $search_fields) = @_;
    
    return undef if !defined $search_term;
    
    # split the search term into its relevant chunks
    my $chunks = _parse_chunks( $search_term );

    # if we're doing a "like" match, then wrap the terms in %...%
    if ($search_type =~ m{\A(?:ilike|like)\z}i) {
        @{ $chunks } = map qq{%$_%}, @{ $chunks };
    }

    # build the where-clause
    my @clauses;
    foreach my $field ( @$search_fields ) {
        push @clauses, $field => { $search_type => $chunks };
    }

    return \@clauses;
}

sub _parse_chunks {
    my ($string) = @_;

    # pull out quoted groups of words
    my @chunks;
    while ($string =~ s{"(.+?)"}{ }g) {
        push @chunks, $1;
    }

    # strip leading and trailing whitespace
    $string =~ s{\A\s+}{};
    $string =~ s{\s+\z}{};

    # split on whitespace - how naive!
    push @chunks, split( m{\s+}, $string );

    return \@chunks;
}

true;

__END__

=pod

=head1 NAME

Dancer::Plugin::SQLSearch - Search helper for relational databases

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use Dancer;
 use Dancer::Plugin::SQLSearch;

 get '/search' => sub {
     my @search_fields = qw( name constellation type ); 
     search (
        query   => param('query'),
        page    => param('page'),
        back    => param('back'),
        fields  => \@search_fields,
        execute => \&actual_search, 
     );
     
     return template 'search';
 };    

 sub actual_search {
     my ($where, $offset, $limit) = @_;
     
     # Perform the actual search in the database
     ....
     
     return $count, \@results;
 } 

=head1 DESCRIPTION

This plugin implements a simple search helper for relational databases. 

Normally, you first present a search page with an input field asking the user for a query string. You then look for the string in your database and present a page with the input field, a table with the first page of results, and pagination links to navigate through the full set of search results. If the user goes to one of the results, you can also have a link back to the search results.

In more detail, the plugin will take a search query, split it into words, and create a data structure suitable for C<SQL::Abstract>. It will also calculate the proper I<offset> and I<limit> for the requested results page, so that you can build the proper SQL query. The actual database query is executed by a subroutine that you will provide.

C<SQL::Abstract> is a simple way to produce SQL. It is the underlying tool for popular ORMs like C<DBIx::DataModel> and C<DBIx::Class>, and they can take the data structure directly and perform the database search for you.

=head1 CONFIGURATION

The main job of this plugin is to build the data structure that C<SQL::Abstract> will turn into an SQL "where" clause. For example, if you entered the search query "orion belt" to the example in the synopsis, the data structure would translate into a where clause equivalent to:

 WHERE name LIKE '%orion%' OR name LIKE '%belt%'
    OR constellation LIKE '%orion%' OR constellation LIKE '%belt%'
    OR type LIKE '%orion%' OR type LIKE '%belt%'

The plugin needs or could use the following configuration options:

=over

=item * Search fields

This is the list of fields where the SQL query will look for the search terms. Required.

=item * Search operator

LIKE by default; optional.

=item * Number of results per page

10 by default. Optional, too.

=back

Your configuration file might look like this:

 plugins:
    SQLSearch:
        fields:
            - name
            - constellation
            - type
        search_operator: ILIKE
        results_per_page: 15

The three configuration options can also be fed to the C<search> method, like C<fields> in the synopsis example.

=head1 METHODS

There is only one method exported by this plugin: C<search>.

=head2 Arguments for C<search>

Besides the configuration options, which can be entered as arguments for C<search>, we have the following arguments:

=over

=item query

This is the string that we will look for in the database. It will be split into words using white space. If the search string is entered between " (double quotes), it will not be split thus allowing for exact phrase matches.

=item page

Page of results to fetch from the database. It is used to calculate the offset for your SQL query.

=item back

If set to true, and if C<query> and C<page> are not defined, the plugin will run the previous search query. The last search query is always saved in the session object.

=item execute

A reference to the subroutine that performs the actual search in the database. It will receive the data structure, an offset and a limit to build an SQL query. It must return the total number of results in the database and the current page of results.

=item advanced

Have you seen search pages that include advanced search parameters? May be they let you restrict your search to a certain period of time, or fix the value of certain database fields.

This argument will take in a hash or array reference that represents these restrictions. This data structure will be "ANDed" to the generated one. Please see the documentation for C<SQL::Abstract> for detailed instructions on how to build your data structure. See the example at the end of this document as well as the test files.

=back

=head2 Output hash reference

The C<search> method will return a hash reference with the following keys:

=over

=item query

The entered search query.

=item page

The requested page number.

=item first_page

Either number 1 or not defined. It is not defined for the initial, blank search page.

=item prev_page

Either the current page number minus one, or undef.

=item next_page

Either the current page plus one, or undef.

=item last_page

Either the number of the last page of results, or undef.

=item count

The number of results for the searched query.

=item results

An array reference of individual results. Results may be whatever you decide, but hash references work nicely within templates. Undef for empty search pages.

=back

=head2 Tokens available in templates

All of the keys returned by C<search> are available within the template. Use them as:

 <% search.query %>
 <% FOREACH result IN search.results %> <% result.field %> <% END %>
 <% search.next_page %>
 
=head1 EXAMPLE

This is a full example of the search routine that you must provide. Note that it uses Dancer::Plugin::Database and SQL::Abstract:

 sub actual_search {
    my ($data_structure, $offset, $limit) = @_;
    
    my $sql = SQL::Abstract->new;
    my ($where_clause, @bind) = $sql->where($data_structure);
    
    my $sql_statement = qq{
        SELECT name, description, latitude, longitude, 
               diameter, depth, colongitude, eponym
        FROM craters
        $where_clause
        LIMIT ?
        OFFSET ?
    };
        
    my $count_statement = qq{
        SELECT count(*) FROM craters $where_clause
    };
    
    my $results = database->selectall_arrayref(
        $sql_statement,
        { Slice => {} },
        @bind, $limit, $offset
    );
    
    my $count = database->selectall_arrayref(
        $count_statement, undef, @bind
    );
    
    return $count->[0][0], $results;
 }


=head1 CREDITS

Many years ago I was looking for a module like this in CPAN, and I found it: Text::SQLSearch::SQL by Chisel Wright. However, that module is part of a larger distribution (actually, it is a full application, Parley) and so I stole a couple of routines from it. These routines are the heart of this plugin.

=head1 AUTHOR

Julio Fraire, julio.fraire at gmail.com

=head1 COPYRIGHT

All rights reserved. This module is free software; you are free to use it, modify it and distribute it under the same terms as Perl itself.

=cut
