#!/usr/bin/perl

use warnings;
use strict;

use Annotator::Schema;
use Annotator::Gtk::View;
use Annotator::Gtk::Controller;

my $model = Annotator::Schema->connect( 'dbi:Pg:dbname=enron', 'enron', 'enron' );
my $view = Annotator::Gtk::View->new( directories => $model->resultset('Document')->directories );

my $controller = Annotator::Gtk::Controller->new( view => $view )->run;

1;
