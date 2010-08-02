package Annotator::Gtk::View::AnnotationSetEditor;
use v5.10;
use Moose;
use MooseX::Types::Moose qw( Bool CodeRef Str );
use Gtk2 '-init';
use constant TRUE => 1;
use constant FALSE => 0;
use Devel::Dwarn;

has 'on_finished' => (
    is => 'rw',
    isa => CodeRef,
    default => sub { sub {} },
);

has 'window_title' => (
    is => 'rw',
    isa => Str,
    default => 'Edit annotationset',
);

has 'window' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_window {
    my $self = shift;
    my $window = Gtk2::Dialog->new;
    $window->add_button( 'gtk-apply', 'apply' );
    $window->set_title ( $self->window_title );
    $window->set_border_width(0);
    return $window;
}

has 'annotations_list_store' => (
    is => 'ro',
    isa => 'Gtk2::ListStore',
    lazy_build => 1,
);

sub _build_annotations_list_store {
    Gtk2::ListStore->new( qw( Glib::String Glib::String Glib::Boolean ) );
}

has 'annotations_list_view' => (
    is => 'ro',
    isa => 'Gtk2::TreeView',
    lazy_build => 1,
);

sub _build_annotations_list_view {
    my $self = shift;
    my $view = Gtk2::TreeView->new( $self->annotations_list_store );

    my $name_renderer = Gtk2::CellRendererText->new;
    $name_renderer->set( editable =>  TRUE );
    $name_renderer->signal_connect( 'edited' => sub { $self->_on_field_edited( @_, 0 ) } );
    my $name_column = Gtk2::TreeViewColumn->new_with_attributes( "Name", $name_renderer );
    $name_column->set_expand( TRUE );
    $name_column->add_attribute( $name_renderer, text => 0 );
    $view->append_column( $name_column );

    my $values_renderer = Gtk2::CellRendererText->new;
    $values_renderer->set( editable => TRUE );
    $values_renderer->signal_connect( 'edited' =>  sub { $self->_on_field_edited( @_, 1 ) } );
    my $values_column = Gtk2::TreeViewColumn->new_with_attributes( "Values", $values_renderer );
    $values_column->set_expand( TRUE );
    $values_column->add_attribute( $values_renderer, text => 1 );
    $view->append_column( $values_column );

    my $tag_renderer = Gtk2::CellRendererToggle->new;
    $tag_renderer->set( activatable => TRUE );
    $tag_renderer->signal_connect( 'toggled' => sub {
        my ( $renderer, $path ) = @_;
        my $iter = $self->annotations_list_store->get_iter_from_string( $path );
        my $old_value = $self->annotations_list_store->get_value( $iter, 2 );
        $self->_on_field_edited( $renderer, $path, ! $old_value, 2 );
    } );
    my $tag_column = Gtk2::TreeViewColumn->new_with_attributes( "Tag?", $tag_renderer );
    $tag_column->add_attribute( $tag_renderer, active => 2 );
    $view->append_column( $tag_column );

    return $view;
}

sub _on_field_edited {
    my ( $self, $renderer, $path, $new_text, $column ) = @_;
    my $store = $self->annotations_list_store;
    my $iter = $store->get_iter_from_string( $path );
    $store->set( $iter, $column => $new_text );
    my $view = $self->annotations_list_view;
    my $next_column = $view->get_column( ( $column + 1 ) % 3 );
    $view->set_cursor( Gtk2::TreePath->new( $path ), $next_column, $column != 1 );
    $view->grab_focus;
}

has '_add_annotation_button' => (
    is => 'ro',
    isa => 'Gtk2::Button',
    lazy_build => 1,
);

sub _build__add_annotation_button {
    Gtk2::Button->new_from_stock( 'gtk-add' );
}

has 'name_field' => (
    is => 'ro',
    isa => 'Gtk2::Entry',
    lazy_build => 1,
);

sub _build_name_field {
    Gtk2::Entry->new
}

has 'description_field' => (
    is => 'ro',
    isa => 'Gtk2::TextView',
    lazy_build => 1,
);

sub _build_description_field {
    Gtk2::TextView->new;
}

sub setup {
    my $self = shift;
    my $table = Gtk2::Table->new( 4, 2, FALSE );
    $table->set_row_spacings( 6 );
    $table->set_col_spacings( 6 );
    $table->attach( Gtk2::Label->new( 'Name:' ), 0, 1, 0, 1, [], [], 10, 0 );
    $table->attach( $self->name_field, 1, 2, 0, 1, [ 'expand', 'fill', ], [], 10, 5 );

    $table->attach( Gtk2::Label->new( 'Description:' ), 0, 1, 1, 2, [], [], 10, 0 );
    $table->attach( _wrap_in_scrolled_window( $self->description_field ), 1, 2, 1, 2, [ 'expand', 'fill' ], [ 'expand', 'fill' ], 10, 5 );
    
    $table->attach( Gtk2::HSeparator->new, 0, 2, 2, 3, [ 'fill' ], [ 'fill' ], 10, 10 );
    #$table->attach( Gtk2::Label->new( 'Annotations:' ), 0, 1, 2, 3, [], [], 10, 0 );
    $table->attach( _wrap_in_scrolled_window( $self->annotations_list_view ), 0, 2, 3, 4, [ 'expand', 'fill' ], [ 'expand', 'fill' ], 10, 5 );

    $self->window->get_content_area->pack_start( $table, TRUE, TRUE, 0 );
    my $hbox = Gtk2::HBox->new;
    $hbox->pack_end( $self->_add_annotation_button, FALSE, FALSE, 10 );
    $self->window->get_content_area->pack_start( $hbox, FALSE, FALSE, 10 );

    $self->_add_annotation_button->signal_connect( clicked => sub {
        my ( $button ) = @_;
        my $store = $self->annotations_list_store;
        my $iter = $store->append;
        $self->annotations_list_view->set_cursor( $store->get_path( $iter ) );
        $self->annotations_list_view->grab_focus;
    } );

    $self->window->signal_connect( response => sub {
        $self->_on_window_close( @_ );
    } );
}

sub run {
    my $self = shift;
    $self->window->show_all;
}

sub _wrap_in_scrolled_window {
    my $widget = shift;
    my $sw = Gtk2::ScrolledWindow->new (undef, undef);
    $sw->set_policy( 'automatic', 'automatic' );
    $sw->add($widget);

    return $sw;
}

sub get_data {
    my $self = shift;
    my @annotations;
    my $store = $self->annotations_list_store;
    my $iter = $store->get_iter_first;
    while ( $iter ) {
        my ( $name, $values, $is_tag ) = $store->get( $iter, 0, 1, 2 );
        push @annotations, { name => $name, values => $values, tag => $is_tag };
        $iter = $store->iter_next( $iter );
    }
    my $description_buffer = $self->description_field->get_buffer;
    return {
        name => $self->name_field->get_text,
        description => $description_buffer->get_text( $description_buffer->get_start_iter, $description_buffer->get_end_iter, FALSE ),
        annotations => \@annotations,
    };
}

sub _on_window_close {
    my ( $self, $window, $response ) = @_;
    my $data = $response eq 'apply' ? $self->get_data : undef;
    $self->on_finished->( $data );
    $window->hide;
}

my $annotationset_window = __PACKAGE__->new( on_finished => sub { Dwarn @_; Gtk2->main_quit } );
$annotationset_window->setup;
$annotationset_window->run;
Gtk2->main;
