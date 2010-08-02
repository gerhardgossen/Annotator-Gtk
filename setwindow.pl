package Annotator::Gtk::View::AnnotationSetEditor;
use v5.10;
use Moose;
use MooseX::Types::Moose qw( Bool Str );
use Gtk2 '-init';
use constant TRUE => 1;
use constant FALSE => 0;

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
    $window->add_button( 'gtk-ok', 0 );
    $window->set_title ( $self->window_title );
    $window->set_border_width(0);
    $window->signal_connect( destroy => sub { Gtk2->main_quit; } );
    return $window;
}

has 'annotations_list_store' => (
    is => 'ro',
    isa => 'Gtk2::ListStore',
    lazy_build => 1,
);

sub _build_annotations_list_store {
    my $self = shift;
    my $store = Gtk2::ListStore->new( qw( Glib::String Glib::String Glib::Boolean ) );
    my $iter = $store->append;
    return $store;
}

has '_is_editing' => (
    is => 'rw',
    isa => Bool,
    default => 0,
);

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

    $view->signal_connect( 'key-release-event' => sub {
        my ( $view, $event ) = @_;
        my ( $path, $column ) = $view->get_cursor;
        return unless ( $path->to_string + 1 ) == $self->annotations_list_store->iter_n_children;
        
        say $event->keyval;
    } );

    return $view;
}

sub _on_field_edited {
    my ( $self, $renderer, $path, $new_text, $column ) = @_;
    warn "Finished editing column $column for path " . $path . ", new text is: $new_text\n";
    my $store = $self->annotations_list_store;
    my $iter = $store->get_iter_from_string( $path );
    $store->set( $iter, $column => $new_text );
    my $view = $self->annotations_list_view;
    my $next_path;
    $next_path = Gtk2::TreePath->new( $path );
    if ( $column == 2 ) {
        say $store->iter_n_children;
        if ( $store->iter_n_children == $path + 1) {
            $store->append;
        }
        $next_path->next;
    }
    warn "next path is: " . $next_path->to_string . "\n";
    my $next_column = $view->get_column( ( $column + 1 ) % 3 );
    $view->set_cursor( $next_path, $next_column, $column != 1 );
    $view->grab_focus;
}

sub setup {
    my $self = shift;
    my $table = Gtk2::Table->new( 4, 2, FALSE );
    $table->set_row_spacings( 6 );
    $table->set_col_spacings( 6 );
    $table->attach( Gtk2::Label->new( 'Name:' ), 0, 1, 0, 1, [], [], 10, 0 );
    $table->attach( Gtk2::Entry->new, 1, 2, 0, 1, [ 'expand', 'fill', ], [], 10, 5 );

    $table->attach( Gtk2::Label->new( 'Description:' ), 0, 1, 1, 2, [], [], 10, 0 );
    $table->attach( wrap_in_scrolled_window( Gtk2::TextView->new ), 1, 2, 1, 2, [ 'expand', 'fill' ], [ 'expand', 'fill' ], 10, 5 );
    
    $table->attach( Gtk2::HSeparator->new, 0, 2, 2, 3, [ 'fill' ], [ 'fill' ], 10, 10 );
    #$table->attach( Gtk2::Label->new( 'Annotations:' ), 0, 1, 2, 3, [], [], 10, 0 );
    $table->attach( wrap_in_scrolled_window( $self->annotations_list_view ), 0, 2, 3, 4, [ 'expand', 'fill' ], [ 'expand', 'fill' ], 10, 5 );

    $self->window->get_content_area->pack_start( $table, TRUE, TRUE, 0 );
    my $hbox = Gtk2::HBox->new;
    $hbox->pack_end( Gtk2::Button->new_from_stock( 'gtk-add' ), FALSE, FALSE, 10 );
    $self->window->get_content_area->pack_start( $hbox, FALSE, FALSE, 10 );

}

sub run {
    my $self = shift;
    $self->window->show_all;
    Gtk2->main;
}

sub wrap_in_scrolled_window {
    my $widget = shift;
    my $sw = Gtk2::ScrolledWindow->new (undef, undef);
    $sw->set_policy( 'automatic', 'automatic' );
    $sw->add($widget);

    return $sw;
}

my $annotationset_window = __PACKAGE__->new;
$annotationset_window->setup;
$annotationset_window->run;
