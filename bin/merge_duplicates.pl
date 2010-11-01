#!/usr/bin/perl

use warnings;
use strict;
use v5.10;
use List::MoreUtils qw( indexes );

use FindBin;
use lib "$FindBin::Bin/../lib";

use Annotator::Schema;

sub mesh;

my $model = Annotator::Schema->connect( 'dbi:Pg:dbname=enron', 'enron', 'enron' );
my $doc_rs = $model->resultset('Document');
my $text_rs = $model->resultset('Text');

my $dups = $doc_rs->search( { title => { '!=' => ''  } }, {
    group_by => [ 'title' ],
    'select' => [
        'title',
        { count => '*' },
        { array_agg => 'document_id' },
        { array_agg => 'text_id' }
    ],
    'as'     => [ 'title', 'count', 'doc_ids', 'text_ids' ],
    having => [ 'count(*)' => { '>' => 1 } ],
} );

$model->txn_do( sub {
    while ( my $row = $dups->next ) {
        my ( $doc_ids, $text_ids ) = map{ $row->get_column( $_ ) } qw ( doc_ids text_ids );
        
        my @texts = map { $_->contents } $text_rs->search( { text_id => { 'IN' => $text_ids } } )->all;

        my @instances = mesh $doc_ids, $text_ids, \@texts;
        while ( @instances > 0 ) {
            my @same_idxs = indexes { $_->[2] eq $instances[0]->[2] } @instances;
            say @same_idxs;
            
            my $first = shift @same_idxs;

            $doc_rs->search( { document_id => { 
                in => [ map { $instances[$_]->[0] } @same_idxs ]
            } } )->update( { text_id => $instances[$first]->[1] } );
            
            foreach ( $first, @same_idxs ) {
                splice @instances, $_, 1;
            }
        }
    }
} );

# from List::MoreUtils, modified to return 'tupels' / array refs
sub mesh (\@\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) {
    my $max = -1;
    $max < $#$_  &&  ($max = $#$_)  for @_;

    map { my $ix = $_; [ map $_->[$ix], @_ ]; } 0..$max; 
}

