use strict;
use warnings;
package Annotator::Gtk::Controller;

use Moose;
use MooseX::Types::Moose qw( Bool );
use namespace::autoclean;

has 'view' => (
    is => 'ro',
    isa => 'Annotator::Gtk::View',
    required => 1,
);

has 'model' => (
    is => 'ro',
    isa => 'Annotator::Schema',
    required => 1,
);

has 'current_user' => (
    is => 'rw',
);

has '_finished_setup' => (
    is => 'rw',
    isa => Bool,
    default => 0,
);

sub setup {
    my $self = shift;
    return if $self->_finished_setup;
    my $view = $self->view;
#    $view->on_messageview_mouse_release( sub { # TODO
#        my $e = shift;
#        $view->show_overlay_at_pos( $e->x_root, $e->y_root );
#    });
    $view->on_messageview_click( sub {
        $view->hide_overlay;
    } );
    $view->on_folder_selected( sub {
        my $foldername = shift;
        $view->populate_message_list( scalar $self->model->resultset('Document')->get_folder_messages( $foldername ) );
    });
    $view->on_message_selected( sub {
        my $message_id = shift;
        my $message_text = $self->model->resultset('Text')->find( $message_id )->contents;
        $view->load_message( $message_id, $message_text );
    } );

    $self->_finished_setup(1);

    $self->current_user( $self->model->resultset('Annotator')->search( name => 'gerhard' )->single ); # FIXME
}

sub run {
    my $self = shift;
    $self->setup;
    $self->view->show;
}

sub create_annotation_set {
    my ( $self, $set_data ) = @_;
    my $set = $set_data->{id}
        ? $self->current_user->find_related( 'annotationsets', { annotationset_id => $set_data->{id} } )
        : $self->current_user->new_related( 'annotationsets', {} );
    $set->set_columns( { name => $set_data->{name}, description => $set_data->{description} } );
    $set->insert_or_update;

    foreach my $annotation_data ( @{ $set_data->{annotations} } ) {
        my $annotation = $annotation_data->{id}
            ? $set->find_related( 'annotation_types', { annotationtype_id => $annotation_data->{id} } )
            : $set->new_related(  'annotation_types', {} );
        $annotation->set_columns( $annotation_data );
        $annotation->insert_or_update;
    }
    return $set->annotationset_id;
}

1;
