use strict;
use warnings;
package Annotator::Gtk::View;

use utf8;
use Gtk2 '-init';
use Moose;
use MooseX::Types::Moose qw( ArrayRef CodeRef HashRef Str );

use constant TRUE  => 1;
use constant FALSE => 0;

use namespace::autoclean;

has 'appname' => (
    is => 'ro',
    isa => Str,
    required => 1,
    default => 'Annotator',
);

has 'window_title' => (
    is => 'rw',
    isa => Str,
    lazy_build => 1,
);

sub _build_window_title {
    return shift->appname;
}

has 'window' => (
    is => 'ro',
    isa => 'Gtk2::Window',
    lazy_build => 1,
);

sub _build_window {
    my $self = shift;
    my $window = Gtk2::Window->new;
    $window->set_title ( $self->window_title );
    $window->set_border_width(0);
    $window->signal_connect( destroy => sub { Gtk2->main_quit; } );
    return $window;
}

has '_statusbar' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build__statusbar {
    Gtk2::Statusbar->new;
}

sub push_status {
    my ( $self, $msg ) = @_;
    $self->_statusbar->push( 0, $msg );
}

has 'menubar' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_menubar {
    my $self = shift;
    my $window = $self->window;

    my @actions_plain = (
            # name,       stock id,      label,      accelerator,  tooltip,               callback
            [ "FileMenu", undef,         "_File",    undef,        undef,                 undef,   ],
            [ "Connect",  'gtk-connect', "_Connect", "<control>N", "Connect to database", undef    ],
            [ "Quit",     'gtk-quit',    "_Quit",    "<control>Q", undef,                 sub { Gtk2->main_quit } ],
    );
    my $ui_basic = "<ui>
      <menubar name='MenuBar'>
        <menu action='FileMenu'> 
         <menuitem action='Connect' position='top'/>
         <separator/>
         <menuitem action='Quit'/>
        </menu>
       </menubar>
       <toolbar name='Toolbar'>
            <placeholder name='optical'>
                    <separator/>
          </placeholder>   
       </toolbar>
    </ui>";

    my $uimanager = Gtk2::UIManager->new;

    my $accelgroup = $uimanager->get_accel_group;
    $window->add_accel_group($accelgroup);
            
    my $actions_basic = Gtk2::ActionGroup->new ("actions_basic");
    $actions_basic->add_actions (\@actions_plain, undef);

    $uimanager->insert_action_group($actions_basic,0);

    $uimanager->add_ui_from_string ($ui_basic);

    return $uimanager->get_widget('/MenuBar');
}

has 'overlay' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_overlay {
    my $overlay = Gtk2::Window->new( 'popup' );
    $overlay->resize( 100, 50 );
    my $hide_overlay = Gtk2::Button->new("Hide");
    $hide_overlay->signal_connect( clicked => sub { $overlay->hide } );
    $overlay->add( $hide_overlay );
    $hide_overlay->show_all;
    return $overlay;
# TODO
}

sub show_overlay_at_pos {
    my ( $self, $x, $y ) = @_;
    my $overlay = $self->overlay;
    $overlay->show;
    $overlay->move( $x, $y );
}

sub hide_overlay {
    shift->overlay->hide;
}

sub wrap_in_scrolled_window {
    my $widget = shift;
    my $sw = Gtk2::ScrolledWindow->new (undef, undef);
    $sw->set_policy( 'automatic', 'automatic' );
    $sw->add($widget);

    return $sw;
}

has 'message_view' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_message_view {
    my $self = shift;
    my $textview = Gtk2::TextView->new;
    $textview->set_size_request( 400, 200 );
    $textview->set_wrap_mode( "word" );
    $textview->set_editable( FALSE );
    my $buffer = $textview->get_buffer;

    $self->window->add_events( [ 'button-release-mask', 'button-press-mask' ] );
    $textview->signal_connect( 'button-release-event' => sub {
        my ( $widget, $e ) = @_;

        if ( ( $self->_get_buffer_selection )[0] ) {
            $self->on_messageview_select->( $e );
        }
        return FALSE; # propagate event
    } );

    $textview->signal_connect( 'button-press-event' => sub {
        my ( $widget, $e ) = @_;
        $self->on_messageview_click->( $e );
        return FALSE; # propagate event
    } );

#    $buffer->signal_connect( 'mark-set' => sub {
#        my ( $buffer, $location, $mark ) = @_;
#        my $name = $mark->get_name;
#        return unless $name && ($name eq 'insert' || $name eq 'selection_bound');
#
#        my ( $start_iter, $end_iter ) = $self->_get_buffer_selection;
#
#        return unless $start_iter;
#        $self->on_messageview_select(); 
#    });
    return $textview;
}

=head2 on_messageview_mouse_release

Called with C<I<GdkEventButton> event>

=cut

has 'on_messageview_select' => (
    is => 'rw',
    isa => CodeRef,
    default => sub { sub { } },
);

has 'on_messageview_click' => (
    is => 'rw',
    isa => CodeRef,
    default => sub { sub { } },
);

has 'message_tags' => (
    is => 'ro',
    isa => ArrayRef[ 'Gtk2::TextTag' ],
    lazy_build => 1,
);

sub _build_message_tags {
    my $self = shift;
    my $buffer = $self->message_view->get_buffer;
    my @colors = map {
        sprintf '%X%X%X', map { int(rand(128) + 127 ) } 0..2;
    } 1..10;
    return [ map {
        $buffer->create_tag( undef, 'background', "#$_" )
    } @colors ];
}

sub get_random_tag {
}

sub highlight_selection {
    my ( $self, $tag ) = @_;

    my ( $start_iter, $end_iter ) = $self->_get_buffer_selection;

    return unless $start_iter;

    $self->message_view->buffer->apply_tag( $tag, $start_iter, $end_iter );
}

sub _get_buffer_selection {
    my $self = shift;
    my $buffer = $self->message_view->get_buffer;
    my $insert_mark = $buffer->get_mark( 'insert' );
    my $bound_mark  = $buffer->get_mark( 'selection_bound' );

    my $insert_iter = $buffer->get_iter_at_mark( $insert_mark );
    my $bound_iter  = $buffer->get_iter_at_mark( $bound_mark  );

    return ( undef, undef ) if $insert_iter->equal( $bound_iter );

    if ( $insert_iter->get_offset < $bound_iter->get_offset ) {
        return ( $insert_iter, $bound_iter );
    } else {
        return ( $bound_iter, $insert_iter );
    }
}

has 'directories' => (
    is => 'ro',
    required => 1,
    isa => HashRef[ HashRef ],
);

has 'foldertree' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_foldertree {
    my $self = shift;

    my $tree_store = Gtk2::TreeStore->new( qw/ Glib::String Glib::UInt / );

    $self->push_status( "Loading folders …" );
    _folder_tree_append_nodes( $tree_store, undef, $self->directories );
    $self->push_status( "Loading folders … Done." );

    my $tree_view = Gtk2::TreeView->new($tree_store);

    my $path_column = Gtk2::TreeViewColumn->new();
    $path_column->set_title("Path");
    $path_column->set_expand( TRUE );
    $path_column->set_max_width( 180 );
    my $image_renderer = Gtk2::CellRendererPixbuf->new;
    $image_renderer->set( stock_id => 'gtk-directory' );
    $path_column->pack_start( $image_renderer, FALSE );
    my $path_renderer = Gtk2::CellRendererText->new;
    $path_column->pack_start( $path_renderer, FALSE );
    $path_column->add_attribute( $path_renderer, text => 0 );
    $tree_view->append_column($path_column);

    my $number_column = Gtk2::TreeViewColumn->new();
    $number_column->set_title("#Msgs");
    $number_column->set_expand( FALSE );
    my $number_renderer = Gtk2::CellRendererText->new;
    $number_column->pack_start( $number_renderer, FALSE );
    $number_column->add_attribute( $number_renderer, text => 1 );
    $tree_view->append_column($number_column);

    $tree_view->set_search_column(0);
    $tree_view->set_reorderable(FALSE);
    $tree_view->set_size_request( 240, -1 );


    $tree_view->signal_connect( 'row-activated' => sub { $self->_on_folder_tree_selected( @_ ) } );
    return $tree_view;
}

sub _folder_tree_append_nodes {
    my ( $tree_store, $parent, $dirs ) = @_;
    foreach my $key ( sort keys %$dirs ) {
        my $iter = $tree_store->append( $parent );
        my $count = $dirs->{$key}->{count};
        $tree_store->set( $iter, 0 => $key, ( defined $count ? (1 => $count) : () ) );
        _folder_tree_append_nodes( $tree_store, $iter, $dirs->{$key}->{children} )
            if defined $dirs->{$key}->{children};
    }
}

has 'message_list' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_message_list {
    my $self = shift;
    my $store = Gtk2::ListStore->new( qw/ Glib::String Glib::String Glib::String / );

    my $view = Gtk2::TreeView->new( $store );

    my $subject_column = Gtk2::TreeViewColumn->new();
    $subject_column->set_title("Subject");
    $subject_column->set_expand( TRUE );
    my $subject_renderer = Gtk2::CellRendererText->new;
    $subject_column->pack_start( $subject_renderer, FALSE );
    $subject_column->add_attribute( $subject_renderer, text => 0 );
    $view->append_column($subject_column);

    my $date_column = Gtk2::TreeViewColumn->new();
    $date_column->set_title("Sent");
    $subject_column->set_max_width( 100 );
    my $date_renderer = Gtk2::CellRendererText->new;
    $date_column->pack_start( $date_renderer, FALSE );
    $date_column->add_attribute( $date_renderer, text => 1 );
    $view->append_column($date_column);
    
    $view->set_size_request( -1, 100 );

    $view->signal_connect( 'row-activated' => sub { $self->_on_message_selected( @_ ) } );

    return $view;
}

sub _on_message_selected {
    my ( $self, $message_list, $path ) = @_;
    my $iter = $message_list->get_model->get_iter( $path );
    my $mid = $message_list->get_model->get( $iter, 2 );
    $self->on_message_selected->( $mid );
}

has 'on_message_selected' => (
    is => 'rw',
    isa => CodeRef,
    default => sub { sub { } },
);

sub load_message {
    my ( $self, $message_id, $message_text ) = @_;

    $self->message_view->get_buffer->set_text( $message_text );
    $self->push_status( "Loaded message '$message_id'." );
}

has 'annotation_list' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_annotation_list {
    my $self = shift;

    my $store = Gtk2::TreeStore->new( 'Glib::String' );
    #$store->insert( 
    return Gtk2::TreeView->new( $store );
}

has [ 'load_annotationset_button', 'add_annotationset_button' ] => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_load_annotationset_button {

    my $load_button = Gtk2::Button->new( 'Load set' );
    $load_button->set_image( Gtk2::Image->new_from_stock( 'gtk-open', 'button' ) );
    return $load_button;
}

sub _build_add_annotationset_button {
    my $add_button = Gtk2::Button->new( 'Create set' );
    $add_button->set_image( Gtk2::Image->new_from_stock( 'gtk-add', 'button' ) );

    return $add_button;
}

has 'on_folder_selected' => (
    is => 'rw',
    isa => CodeRef,
    default => sub { sub {} },
);

sub _on_folder_tree_selected {
    my ( $self, $tree_view, $path, $column ) = @_;
    my $model = $tree_view->get_model;
    my @idxs = split /:/, $path->to_string;
    my $parent = undef;
    my @parts;
    foreach my $idx ( @idxs ) {
        $parent = $model->iter_nth_child( $parent, $idx );
        push @parts, $model->get( $parent, 0 );
    }
    my $folder = join '/', @parts;
    $self->push_status( "Loading folder '$folder'" );
    $self->on_folder_selected->( $folder );
}

sub populate_message_list {
    my ( $self, $msg_cursor ) = @_;
    $self->push_status( "Loading messages  …" );
    my $model = $self->message_list->get_model;
    $model->clear;
    while ( my $message = $msg_cursor->next ) {
        my $iter = $model->append;
        $model->set( 
            $iter,
            0 => $message->title,
            1 => $message->date->strftime('%F %T'),
            2 => $message->text_id
        );
    }

    $self->push_status( "Loading messages … Done." );
}

sub BUILD {
    my $self = shift;

    my $window = $self->window;
    my $vbox = Gtk2::VBox->new(FALSE, 0);
    $window->add($vbox);

    my $content_box = Gtk2::HPaned->new;
    $content_box->pack1( wrap_in_scrolled_window( $self->foldertree ), FALSE, TRUE );
    my $rhs = Gtk2::HPaned->new;
    my $middle_panel = Gtk2::VBox->new;
    $rhs->pack1( $middle_panel, TRUE, TRUE );
    $middle_panel->pack_start( wrap_in_scrolled_window( $self->message_list ), TRUE, TRUE, 0 );
    $middle_panel->pack_start( wrap_in_scrolled_window( $self->message_view ), TRUE, TRUE, 0);
    $content_box->pack2( $rhs, TRUE, TRUE );

    my $annotation_panel = Gtk2::VBox->new;
    $annotation_panel->pack_start( $self->annotation_list, TRUE, TRUE, 0 );
    $annotation_panel->pack_end( $self->load_annotationset_button, FALSE, FALSE, 0 );
    $annotation_panel->pack_end( $self->add_annotationset_button, FALSE, FALSE, 0 );
    $rhs->pack2( $annotation_panel, TRUE, TRUE );

    $vbox->pack_start( $self->menubar, FALSE, FALSE, 0 );
    $vbox->pack_start( $content_box, TRUE, TRUE, 0 );

    $vbox->pack_end( $self->_statusbar, FALSE, FALSE, 0 );
}

sub show {
    my $self = shift;

    $self->window->show_all;
    Gtk2->main;
}

1;

__END__
sub create_overlay {
    my $overlay = Gtk2::Window->new( 'popup' );
    $overlay->resize( 100, 50 );
    my $hide_overlay = Gtk2::Button->new("Hide");
    $hide_overlay->signal_connect( clicked => sub { $overlay->hide } );
    $overlay->add( $hide_overlay );
    $hide_overlay->show_all;
    return $overlay;
}
my $overlay = create_overlay;

-------------------
----------------


