package Annotator::Gtk::View::AnnotationMutationHandler;

use Moose::Role;

requires qw( annotation_added annotation_changed annotation_removed );

1;
