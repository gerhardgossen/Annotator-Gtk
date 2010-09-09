package Annotator::Gtk::View::MessageAnnotations;

use Moose;
use MooseX::Types::Moose qw( ArrayRef );
use MooseX::NonMoose;
use Annotator::Gtk::View::Constants qw( :bool :message_annotations );

extends 'Gtk2::TreeView';
with 'Annotator::Gtk::View::AnnotationMutationHandler';

sub FOREIGNBUILDARGS { () }

has 'annotation_sets' => (
    is => 'ro',
    isa => 'Annotator::Gtk::View::AnnotationSetList',
    required => 1,
);

has '_mutation_listeners' => (
    is => 'ro',
    isa => ArrayRef[ 'Annotator::Gtk::View::AnnotationMutationHandler' ],
    default => sub { [] },
    traits => [ 'Array' ],
    handles => {
        add_mutation_listener   => 'push',
        _map_mutation_listeners => 'map',
    },
);

has 'model' => (
    is => 'ro',
    isa => 'Gtk2::TreeModel',
    lazy_build => 1,
);

sub _build_model {
    my $store = Gtk2::ListStore->new( qw/ Glib::Int Glib::Int Glib::String Glib::String Glib::String Glib::Int / );
    $store->set_sort_column_id( MA_START, 'ascending' );
    return $store;
}

sub _notify_mutation {
    my ( $self, $mutation, @args ) = @_;
    $self->_map_mutation_listeners( sub { $_->$mutation( @args ) } );
}

has _current_message => (
    is => 'rw',
    isa => 'Annotator::Schema::Result::Text',
);

sub load_message_annotations {
    my ( $self, $message ) = @_;

    $self->_current_message( $message );
    my $store = $self->model;
    $store->clear;

    my $annotations = $message->annotations;
    while ( my $annotation = $annotations->next ) {
        my $type = $annotation->annotation_type;

        my $set = $type->annotationset->annotationset_id;
        $self->annotation_sets->load_annotation_set( $set );

        my $name = $self->annotation_sets->get_name_for_id( $annotation->annotationtype_id );
        my $iter = $store->append;
        $store->set( $iter,
            MA_NAME()  => $name,
            MA_VALUE() => $annotation->value,
            MA_START() => $annotation->start_pos,
            MA_END()   => $annotation->end_pos,
            MA_ID()    => $annotation->annotation_id,
            MA_ANNID() => $annotation->annotationtype_id,
        );

        $self->_notify_mutation( 'annotation_added',
            $annotation->annotation_id,
            $annotation->annotationtype_id,
            $annotation->value,
            $annotation->start_pos,
            $annotation->end_pos
        );
    }
}

sub annotation_added {
    my ( $self, $annotation_id, $annotationtype_id, $value, $start, $end ) = @_;

    my $store = $self->model;
    my $iter = $store->append;
    $store->set( $iter,
        MA_NAME,  $self->annotation_sets->get_name_for_id( $annotationtype_id ),
        MA_VALUE, $value,
        MA_START, $start,
        MA_END,   $end,
        MA_ID,    $annotation_id,
        MA_ANNID, $annotationtype_id,
    );
    my $annotation = $self->_current_message->create_related( annotations => {
        annotationtype_id => $annotationtype_id,
        start_pos         => $start,
        end_pos           => $end,
        value             => $value,
        creator_id        => 1, # TODO
    });

    $annotation_id = $annotation->annotation_id;

    $self->_notify_mutation( annotation_added => $annotation_id, $annotationtype_id, $value, $start, $end );
    return $iter;
}

sub annotation_changed {
    my ( $self, $iter, $annotation_id, $annotationtype_id, $value, $start, $end ) = @_;
    $self->_notify_mutation( annotation_changed => $iter, $annotation_id, $annotationtype_id, $value, $start, $end );
    $self->model->set( $iter,
        MA_NAME,  $self->annotation_sets->get_name_for_id( $annotationtype_id ),
        MA_VALUE, $value,
        MA_START, $start,
        MA_END,   $end,
        MA_ID,    $annotation_id,
        MA_ANNID, $annotationtype_id,
    );

    my $annotation = $self->_current_message
        ->find_related( annotations => {
            annotation_id     => $annotation_id,
        } )->update( {
            annotationtype_id => $annotationtype_id,
            start_pos         => $start,
            end_pos           => $end,
            value             => $value,
        } );
}

sub annotation_removed {
    my ( $self, $iter ) = @_;
    $self->_notify_mutation( annotation_removed => $iter );
    $self->_current_message->delete_related( annotations => {
        annotation_id => $self->model->get( $iter, MA_ID )
    } );
    $self->model->remove( $iter );
}

sub BUILD {
    my $self = shift;

    $self->set_model( $self->model );

    my ( $start_renderer, $end_renderer, $name_renderer, $value_renderer )
        = map { Gtk2::CellRendererText->new } 1..4;

    my $name_column = Gtk2::TreeViewColumn->new_with_attributes( "Name", $name_renderer, text => MA_NAME );
    $name_column->set_expand( TRUE );
    $self->append_column( $name_column );

    my $value_column = Gtk2::TreeViewColumn->new_with_attributes( "Value", $value_renderer, text => MA_VALUE );
    $value_column->set_expand( TRUE );
    $self->append_column( $value_column );

    my $start_column = Gtk2::TreeViewColumn->new_with_attributes( "Start", $start_renderer, text => MA_START );
    #$start_column->set_expand( TRUE );
    $self->append_column( $start_column );

    my $end_column = Gtk2::TreeViewColumn->new_with_attributes( "End", $end_renderer, text => MA_END );
    #$end_column->set_expand( TRUE );
    $self->append_column( $end_column );
    return $self;
}

__PACKAGE__->meta->make_immutable;
