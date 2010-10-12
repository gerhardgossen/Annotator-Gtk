package Annotator::Gtk::View::AnnotationSetList;

use Gtk2 '-init';
use Moose;
use MooseX::Types::Moose qw( ArrayRef CodeRef HashRef );
use MooseX::NonMoose;
use namespace::autoclean;
use Annotator::Gtk::View::Constants qw( :bool :annotations );

extends 'Gtk2::VBox';

sub FOREIGNBUILDARGS { () }

sub BUILD {
    my $self = shift;
    $self->pack_start( $self->annotation_list, TRUE, TRUE, 0 );
    $self->pack_end( $self->_load_annotationset_button, FALSE, FALSE, 0 );
    $self->pack_end( $self->_add_annotationset_button, FALSE, FALSE, 0 );
}

has 'annotation_model' => (
    is => 'ro',
    isa => 'Gtk2::TreeModel',
    required => 1,
);

has 'message_buffer' => (
    is => 'ro',
    isa => 'Gtk2::TextBuffer',
    required => 1,
);

has [ 'get_annotation_set', 'get_annotation_sets', 'add_message_tag' ] => (
    is => 'ro',
    isa => CodeRef,
    required => 1,
);

has 'load_window' => (
    is => 'ro',
    isa => 'Gtk2::Dialog',
    lazy_build => 1,
);

sub _build_load_window {
    my $window = Gtk2::Dialog->new;
    $window->set_title( "Load Annotation Set" );
    $window->add_button( 'gtk-open', 'apply' );
    $window->add_button( 'gtk-cancel', 'cancel' );
    $window->set_border_width( 0 );
    return $window;
}

has 'set_list_store' => (
    is => 'ro',
    isa => 'Gtk2::ListStore',
    lazy_build => 1,
);

sub _build_set_list_store {
    my $self = shift;
    my $store = Gtk2::ListStore->new( qw/ Glib::String Glib::String / );
    my $cursor = $self->get_annotation_sets->();
    while ( my $set = $cursor->next ) {
        my $iter = $store->append;
        $store->set( $iter, 0 => $set->name, 1 => $set->annotationset_id );
    }
    return $store;
}

has 'set_list_view' => (
    is => 'ro',
    isa => 'Gtk2::TreeView',
    lazy_build => 1,
);

sub _build_set_list_view {
    my $self = shift;

    my $view = Gtk2::TreeView->new( $self->set_list_store );

    my $name_renderer = Gtk2::CellRendererText->new;
    my $name_column = Gtk2::TreeViewColumn->new_with_attributes( "Name", $name_renderer );
    $name_column->set_expand( TRUE );
    $name_column->add_attribute( $name_renderer, text => 0 );

    $view->append_column( $name_column );
    $view->set_size_request( -1, 90 );

    return $view;
}

sub selected_set {
    my $self = shift;
    my $selection = $self->set_list_view->get_selection;
    if ( $selection->count_selected_rows == 0 ) {
        return undef;
    }
    my $iter = $selection->get_selected;
    return $self->set_list_store->get( $iter, 1 );
}

sub _show_load_window {
    my $self = shift;
    $self->load_window->get_content_area->pack_start( $self->set_list_view, TRUE, TRUE, 10 );

    $self->load_window->signal_connect( response => sub {
        my ( $window, $response ) = @_;
        if ( $response eq 'apply' ) {
            $self->load_annotation_set( $self->selected_set );
        }
        $window->destroy;
    } );
    $self->load_window->show_all;
}

has [ '_load_annotationset_button', '_add_annotationset_button' ] => (
    is => 'ro',
    lazy_build => 1,
);

sub _build__load_annotationset_button {
    my $self = shift;

    my $load_button = Gtk2::Button->new( 'Load set' );
    $load_button->set_image( Gtk2::Image->new_from_stock( 'gtk-open', 'button' ) );
    $load_button->signal_connect( clicked => sub {
        $self->_show_load_window;
    } );
    return $load_button;
}

has '_loaded_sets' => (
    is => 'ro',
    isa => HashRef,
    default => sub { {} },
);

sub load_annotation_set {
    my ( $self, $set_id ) = @_;
    return unless $set_id;
    return if $self->_loaded_sets->{ $set_id };
    #$self->push_status( "Loading set $set_id" );
    my $set = $self->get_annotation_set->( $set_id );
    unless ( $set ) {
        die "There is no annotation set with id '$set_id'";
    }
    my $store = $self->annotation_model;
    if ( $store->isa( 'Gtk2::TreeModelFilter' ) ) {
        $store = $store->get_model;
    }
    my $iter = $store->append( undef );
    $store->set( $iter, 0 => $set->name );
    my $types = $set->annotation_types;
    while ( my $type = $types->next ) {
        my $fullname = $set->name . '::' . $type->name;
        my $tag = $self->tag_for_annotation( $fullname );
        my $color = $tag->get( 'background-gdk' )->to_string;
        my $child_iter = $store->append( $iter );
        $store->set( $child_iter,
            AL_NAME  , $fullname, #$type->name,
            AL_ID    , $type->annotationtype_id,
            AL_COLOR , $color,
            AL_IS_TAG, $type->is_tag
        );
        my @values = split /\s*\|\s*/, $type->values;
        foreach my $value ( @values ) {
            my $value_iter = $store->append( $child_iter );
            $store->set( $value_iter, AL_NAME, $value );
        }
    }
    $self->annotation_list->expand_to_path( $store->get_path( $iter ) );
    $self->_loaded_sets->{ $set_id }++;
}

sub _build__add_annotationset_button {
    my $self = shift;
    my $add_button = Gtk2::Button->new( 'Create set' );
    $add_button->set_image( Gtk2::Image->new_from_stock( 'gtk-add', 'button' ) );
    $add_button->signal_connect( clicked => sub {
        my $creator = Annotator::Gtk::View::AnnotationSetEditor->new(
            on_finished => sub { $self->_created_annotation_set( @_ ) },
        );
        $creator->run;
    } );

    return $add_button;
}

sub _created_annotation_set {
    my ( $self, $set_data ) = @_;
    return unless $set_data;
    my $set_id = $self->controller->create_annotation_set( $set_data );
    $self->load_annotation_set( $set_id );
}

has 'annotation_list' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_annotation_list {
    my $self = shift;
    my $view = Gtk2::TreeView->new( $self->annotation_model );
    $view->set_level_indentation( -16 );

    my $name_column = Gtk2::TreeViewColumn->new;
    my $name_renderer = Gtk2::CellRendererText->new;
    $name_column->pack_start( $name_renderer, TRUE );
    $name_column->add_attribute( $name_renderer, text => AL_NAME);
    $name_column->add_attribute( $name_renderer, background => AL_COLOR );

    $view->append_column( $name_column );


    $view->signal_connect( row_activated => sub {
        my ( $view, $path, $columns ) = @_;
        my $model = $view->get_model;
        my $iter = $model->get_iter( $path );
        my $is_tag = $model->get( $iter, AL_IS_TAG );
        return unless $is_tag;
        $self->add_message_tag->( $model->get( $iter, AL_ID ) );
    } );
    return $view;
}

sub _random_color {
        sprintf '#%X%X%X', map { int(rand(128) + 127 ) } 0..2;
}

sub tag_for_annotation {
    my ( $self, $name ) = @_;
    unless ( defined $self->message_tags->{ $name } ) {
        my $buffer = $self->message_buffer;
        $self->message_tags->{ $name } = $buffer->create_tag( $name, 'background', _random_color );
    }
    $self->message_tags->{ $name };
}

has 'message_tags' => (
    is => 'ro',
    isa => HashRef[ 'Gtk2::TextTag' ],
    default => sub { {} },
);

sub get_name_for_id {
    my ( $self, $id ) = @_;
    my $model = $self->annotation_model;
    my $name;
    $model->foreach( sub {
        my ( $model, $path, $iter ) = @_;
        if ( $model->get( $iter, AL_ID ) == $id ) {
            $name = $model->get( $iter, AL_NAME );
            return TRUE;
        } else {
            return FALSE;
        }
    } );
    return $name;
}

1;
