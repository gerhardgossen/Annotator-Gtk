#!/usr/bin/perl

use warnings;
use strict;
use v5.10;
use Email::Simple;
use Mail::Address;

use Annotator::Schema;

my $model = Annotator::Schema->connect( 'dbi:Pg:dbname=enron', 'enron', 'enron' );

my $documents = $model->resultset("Document")->search(
    {}, {
        join => 'text',
        columns => [ qw( document_id text.metadata ) ],
    });
say $documents->count . " rows found";

while ( my $doc = $documents->next ) {
    my $email = Email::Simple->new( $doc->text->metadata );
    my @addresses = Mail::Address->parse( $email->header( "From" ) );
    my @clean_addresses = map { $_->name || $_->user } @addresses;
    say $clean_addresses[0];
    $doc->sender( $clean_addresses[0] );
    $doc->update;
}

