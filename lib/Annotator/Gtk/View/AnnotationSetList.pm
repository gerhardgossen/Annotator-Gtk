package Annotator::Gtk::View::AnnotationSetList;

use Gtk2 '-init';
use Moose;
use MooseX::Types::Moose qw( ArrayRef CodeRef );
use namespace::autoclean;
use constant TRUE => 1;
use constant FALSE => 0;

has 'window' => (
    is => 'ro',
    isa => 'Gtk2::Dialog',
    lazy_build => 1,
);

sub _build_window {
    my $window = Gtk2::Dialog->new;
    $window->set_title( "Load Annotation Set" );
    $window->add_button( 'gtk-open', 'apply' );
    $window->add_button( 'gtk-cancel', 'cancel' );
    $window->set_border_width( 0 );
    return $window;
}

has 'annotation_sets' => (
    is => 'ro',
    isa => 'DBIx::Class::ResultSet',
    required => 1,
);

has 'set_list_store' => (
    is => 'ro',
    isa => 'Gtk2::ListStore',
    lazy_build => 1,
);

sub _build_set_list_store {
    my $self = shift;
    my $store = Gtk2::ListStore->new( qw/ Glib::String Glib::String / );
    while ( my $set = $self->annotation_sets->next ) {
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

has 'on_load_set' => (
    is => 'rw',
    isa => CodeRef,
    default => sub { sub { } },
);

sub selected_set {
    my $self = shift;
    my $selection = $self->set_list_view->get_selection;
    if ( $selection->count_selected_rows == 0 ) {
        return undef;
    }
    my $iter = $selection->get_selected;
    return $self->set_list_store->get( $iter, 1 );
}

sub setup {
    my $self = shift;
    $self->window->get_content_area->pack_start( $self->set_list_view, TRUE, TRUE, 10 );

    $self->window->signal_connect( response => sub {
        my ( $window, $response ) = @_;
        if ( $response eq 'apply' ) {
            $self->on_load_set->( $self->selected_set );
        }
        $self->window->destroy;
    } );
}

sub run {
    my $self = shift;
    $self->setup;
    $self->window->show_all;
}

1;
