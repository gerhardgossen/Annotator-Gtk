use strict;
use warnings;
package Annotator::Gtk::View;

use feature 'say', 'switch';

use utf8;
use Gtk2 '-init';
use Moose;
use MooseX::Types::Moose qw( ArrayRef CodeRef HashRef Int Str );
use Annotator::Gtk::View::AnnotationSetEditor;
use Annotator::Gtk::View::AnnotationSetList;

use constant TRUE  => 1;
use constant FALSE => 0;

use constant AL_NAME  => 0;
use constant AL_ID    => 1;
use constant AL_COLOR => 2;

use constant {
    MA_START => 0,
    MA_END   => 1,
    MA_NAME  => 2,
    MA_VALUE => 3,
    MA_ID    => 4,
    MA_ANNID => 5,
};

use namespace::autoclean;

has 'controller' => (
    is => 'rw',
    isa => 'Annotator::Gtk::Controller',
);

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

has _overlay_rows => (
    traits => [ 'Counter' ],
    is => 'rw',
    isa => Int,
    default => -1,
    handles => {
        _next_overlay_row => 'inc',
    },
);

sub _build_overlay {
    my $self = shift;
    my $overlay = Gtk2::Window->new( 'popup' );
    my $vbox = Gtk2::VBox->new;
    $overlay->add( $vbox );
    my $layout = Gtk2::Table->new( 1, 3, FALSE );
    $layout->set_name( 'annotations_container' );
    $vbox->pack_start( $layout, FALSE, TRUE, 0 );
    $self->_add_overlay_annotation_row( $layout, $self->_next_overlay_row );

    my $hb_wrapper = Gtk2::HBox->new;
    my $add_row = Gtk2::Button->new_from_stock( 'gtk-add' );
    $add_row->signal_connect( clicked => sub {
        $self->_add_overlay_annotation_row( $layout, $self->_next_overlay_row );
    } );
    $hb_wrapper->pack_start( $add_row, FALSE, FALSE, 6 );

    my $hide_overlay = Gtk2::Button->new("Hide");
    $hide_overlay->signal_connect( clicked => sub { $self->hide_overlay } );
    $hb_wrapper->pack_end( $hide_overlay, FALSE, FALSE, 6 );
    $vbox->pack_end( $hb_wrapper, FALSE, FALSE, 0 );
    $vbox->show_all;
    return $overlay;
}

sub _add_overlay_annotation_row {
    my ( $self, $layout, $row ) = @_;

    $layout->resize( $row + 1, 3 );
    my $opts = [ qw/ expand shrink / ];
    my $padding = 6;

    my $annotation_box = Gtk2::ComboBox->new_with_model( $self->annotations_only_model );
    $annotation_box->set_name( "annotation_$row" );
    $annotation_box->set_size_request( 80, -1 );

    my $ab_renderer = Gtk2::CellRendererText->new;
    $annotation_box->pack_start( $ab_renderer, TRUE );
    $annotation_box->add_attribute( $ab_renderer, 'text', 0 );

    my $value_box = Gtk2::ComboBox->new;
    $value_box->set_name( "value_$row" );
    $value_box->set_size_request( 80, -1 );

    my $val_renderer = Gtk2::CellRendererText->new;
    $value_box->pack_start( $val_renderer, TRUE );
    $value_box->add_attribute( $val_renderer, text => 0 );

    $annotation_box->signal_connect( 'changed', sub {
        my $box = shift;
        my $active_iter = $box->get_active_iter;
        if ( $active_iter ) {
            my $path = $self->annotations_only_model->get_path( $active_iter );
            $value_box->set_model( Gtk2::TreeModelFilter->new( $self->annotation_model, $path ) );
        }
    } );

    my $remove = Gtk2::Button->new;
    $remove->set_image( Gtk2::Image->new_from_stock( 'gtk-remove', 'button' ) );
    $remove->set_name( "remove_$row" );
    $remove->signal_connect( clicked => sub { $self->_remove_overlay_annotation_row( $row ) } );

    $layout->attach( $annotation_box, 0, 1, $row, $row + 1, $opts, $opts, $padding, $padding );
    $layout->attach( $value_box, 1, 2, $row, $row + 1, $opts, $opts, $padding, $padding );
    $layout->attach( $remove, 2, 3, $row, $row + 1, $opts, $opts, $padding, $padding );

    $layout->show_all;
}

sub _remove_overlay_annotation_row {
    my ( $self, $row ) = @_;
    my $table = $self->_get_overlay_table;
    my @row_elements = $table->get_children;
    return if $row > scalar( @row_elements ) / $table->get( 'n-columns' );
    foreach my $widget ( @row_elements ) {
        my @opts = map { $table->child_get( $widget, $_ ) } (
            "left-attach", "right-attach",
            "top-attach", "bottom-attach",
            "x-options", "y-options",
            "x-padding", "y-padding"
        );
        my $current_row = $opts[2];
        if ( $current_row == $row ) {
            $widget->destroy;
        } elsif ( $current_row > $row ) {
            $opts[2]--;
            $opts[3]--;
            $table->remove( $widget );
            $table->attach( $widget, @opts );
        }
    }
    $table->resize( $table->get( 'n-rows' ) - 1, $table->get( 'n-columns' ) );
    $table->show_all;

    $self->_overlay_rows( $self->_overlay_rows - 1);
}

sub show_overlay_at_pos {
    my ( $self, $x, $y ) = @_;
    my $overlay = $self->overlay;
    $overlay->show;
    $overlay->move( $x, $y );
}

sub _get_overlay_table {
    my $self = shift;
    my $container = ( ( $self->overlay->get_children )[0]->get_children )[0];
    unless ( $container->get_name eq 'annotations_container' ) {
        die 'Widget hierarchy is wrong, expected annotations_container';
    }
    return $container;
}
sub hide_overlay {
    my $self = shift;
    return unless $self->overlay->get( 'visible' );
    my @annotations;
    foreach my $child ( $self->_get_overlay_table->get_children ) {
        given ( $child->get_name ) {
            when( /^value_(\d+)/ ) {
                my $value = _get_combo_value( $child, AL_NAME );
                $annotations[ $1 ]->{value} = $value;
            }
            when( /^annotation_(\d+)/ ) {
                my $name = _get_combo_value( $child, AL_NAME );
                $annotations[ $1 ]->{annotation} = $name;
                my $type_id = _get_combo_value( $child, AL_ID );
                $annotations[ $1 ]->{annotationtype_id} = $type_id;
            }
        }
    }
    Dwarn( \@annotations );
    my $message_buffer = $self->message_view->get_buffer;
    my ( $start, $end ) = map { $_->get_offset } $self->_get_buffer_selection;
    foreach my $annotation ( @annotations ) {
        next unless $annotation->{annotation};
        $self->add_message_annotation( %$annotation, start => $start, end => $end );
    }

    $self->overlay->hide;
    $self->reset_overlay;
}

sub add_message_annotation {
    my ( $self, %args ) = @_;

    my $tag = $self->message_tags->{ $args{annotation} };
    $self->highlight_annotation( $tag, $args{start}, $args{end} ) if $tag;

    my $store = $self->message_annotations;

    my $iter = $store->append;
    $store->set( $iter,
        MA_NAME,  $args{annotation},
        MA_VALUE, $args{value},
        MA_START, $args{start},
        MA_END,   $args{end},
        MA_ID,    $args{annotation_id},
        MA_ANNID, $args{annotationtype_id},
    );
}

sub reset_overlay {
    my $self = shift;
    if ( $self->_overlay_rows < 0 ) {
       $self->_add_overlay_annotation_row( $self->_next_overlay_row );
    } else {
        while ( $self->_overlay_rows > 0 ) {
            $self->_remove_overlay_annotation_row( $self->_overlay_rows );
        }
        my $table = $self->_get_overlay_table;
        foreach my $widget ( $table->get_children ) {
            if ( $widget->isa( 'Gtk2::ComboBox' ) ) {
                $widget->set_active( -1 );
            }
        }
    }
}

sub _get_combo_value {
    my ( $box, $col ) = @_;
    my $iter = $box->get_active_iter;
    return $iter ? $box->get_model->get( $iter, $col ) : undef;
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
            $self->on_messageview_select->( $self, $e );
        }
        return FALSE; # propagate event
    } );

    $textview->signal_connect( 'button-press-event' => sub {
        my ( $widget, $e ) = @_;
        $self->on_messageview_click->( $e );
        return FALSE; # propagate event
    } );

#    $buffer->signal_connect( 'mark-set' => sub { TODO
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
    lazy_build => 1,
);

use Devel::Dwarn;
sub _build_on_messageview_select {
    return sub {
        my ( $self, $e ) = @_;
        my $buffer = $self->message_view->get_buffer;
        $self->show_overlay_at_pos( $e->x_root, $e->y_root );
        return FALSE;
    }
}

has 'on_messageview_click' => (
    is => 'rw',
    isa => CodeRef,
    default => sub { sub { } },
);

has 'message_tags' => (
    is => 'ro',
    isa => HashRef[ 'Gtk2::TextTag' ],
    default => sub { {} },
);

sub _random_color {
        sprintf '#%X%X%X', map { int(rand(128) + 127 ) } 0..2;
}
sub _create_new_annotation_tag {
    my ( $self, $name ) = @_;
    $self->message_view->get_buffer->create_tag( $name, 'background', _random_color );
}

sub highlight_annotation {
    my ( $self, $tag, $start, $end ) = @_;

    my $buffer = $self->message_view->get_buffer;
    my $start_iter = $buffer->get_iter_at_offset( $start );
    my $end_iter = $buffer->get_iter_at_offset( $end );
    #my ( $start_iter, $end_iter ) = $self->_get_buffer_selection;

    return unless $start_iter;

    $self->message_view->get_buffer->apply_tag( $tag, $start_iter, $end_iter );
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

has 'current_message' => (
    is => 'rw',
    isa => 'Annotator::Schema::Result::Text',
    trigger => \&_load_message,
);

sub _load_message {
    my ( $self, $message, $old_message ) = @_;

    $self->_save_message_annotations( $old_message );

    $self->message_view->get_buffer->set_text( $message->contents );
    $self->_load_message_annotations( $message );
    $self->push_status( "Loaded message '" . $message->text_id . "'." );
}

sub _save_message_annotations {
    my ( $self, $message ) = @_;

    my $annotation_model = $self->message_annotations;
    
    my $iter = $annotation_model->get_iter_first;
    
    my $rs = $self->model->resultset('Annotation');
    while ( $iter ) {
        my $annotation_id = $annotation_model->get( $iter, MA_ID );
        $message->update_or_create_related( 'annotations', {
            $annotation_id ? ( annotation_id => $annotation_id ) : (),
            annotationtype_id => $annotation_model->get( $iter, MA_ANNID ),
            start_pos         => $annotation_model->get( $iter, MA_START ),
            end_pos           => $annotation_model->get( $iter, MA_END ),
            value             => $annotation_model->get( $iter, MA_VALUE ),
            creator_id        => 1, # TODO
        });

        $iter = $annotation_model->iter_next( $iter );
    }
# TODO
}

sub _load_message_annotations {
    my ( $self, $message ) = @_;

    my $annotation_model = $self->message_annotations;
    $annotation_model->clear;

    my $annotations = $message->annotations;
    while ( my $annotation = $annotations->next ) {
        my $type = $annotation->annotation_type;
        my $name = $type->annotationset->name . '::' . $type->name;
        my $iter = $annotation_model->append;
        $annotation_model->set( $iter,
            MA_NAME,  $name, # TODO: get name 
            MA_VALUE, $annotation->value,
            MA_START, $annotation->start_pos,
            MA_END,   $annotation->end_pos,
            MA_ID,    $annotation->annotation_id,
            MA_ANNID, $annotation->annotationtype_id,
        );
    }
# TODO
}

has 'annotation_model' => (
    is => 'ro',
    isa => 'Gtk2::TreeModel',
    lazy_build => 1,
);

sub _build_annotation_model {
    Gtk2::TreeStore->new( qw/ Glib::String Glib::UInt Glib::String / );
}

has 'annotation_list' => (
    is => 'ro',
    lazy_build => 1,
);

has 'annotations_only_model' => (
    is => 'ro',
    isa => 'Gtk2::TreeModel',
    lazy_build => 1,
);

sub _build_annotations_only_model {
    my $self = shift;
    my $filtered_annotations = Gtk2::TreeModelFilter->new( $self->annotation_model );
    $filtered_annotations->set_visible_func( sub {
        my ( $store, $iter ) = @_;
        my $path = $store->get_path( $iter )->to_string;
        return ( $path =~ s/:/:/g ) < 2; # Only show first 2 levels (set+annotation)
    } );
    return $filtered_annotations;
}

sub _build_annotation_list {
    my $self = shift;
    my $view = Gtk2::TreeView->new( $self->annotations_only_model );
    $view->set_level_indentation( -16 );

    my $name_column = Gtk2::TreeViewColumn->new;
    my $name_renderer = Gtk2::CellRendererText->new;
    $name_column->pack_start( $name_renderer, TRUE );
    $name_column->add_attribute( $name_renderer, text => AL_NAME);
    $name_column->add_attribute( $name_renderer, background => AL_COLOR );

    $view->append_column( $name_column );

    return $view;
}

has 'model' => (
    is => 'rw',
    isa => 'Annotator::Schema',
    required => 1,
);

has [ 'load_annotationset_button', 'add_annotationset_button' ] => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_load_annotationset_button {
    my $self = shift;

    my $load_button = Gtk2::Button->new( 'Load set' );
    $load_button->set_image( Gtk2::Image->new_from_stock( 'gtk-open', 'button' ) );
    $load_button->signal_connect( clicked => sub {
        my $lister = Annotator::Gtk::View::AnnotationSetList->new(
            on_load_set => sub { $self->load_annotation_set( @_ ); },
            annotation_sets => $self->model->resultset('AnnotationSet')->search_rs,
        );
        $lister->run;
    } );
    return $load_button;
}

sub load_annotation_set {
    my ( $self, $set_id ) = @_;
    return unless $set_id;
    $self->push_status( "Loading set $set_id" );
    my $set = $self->model->resultset('AnnotationSet')->find( $set_id );
    unless ( $set ) {
        die "There is no annotation set with id '$set_id'";
    }
    my $store = $self->annotation_model;
    my $iter = $store->append( undef );
    $store->set( $iter, 0 => $set->name );
    my $types = $set->annotation_types;
    while ( my $type = $types->next ) {
        my $fullname = $set->name . '::' . $type->name;
        my $tag = $self->_create_new_annotation_tag( $fullname );
        $self->message_tags->{ $fullname } = $tag;
        my $color = $tag->get( 'background-gdk' )->to_string;
        my $child_iter = $store->append( $iter );
        $store->set( $child_iter,
            AL_NAME  , $fullname, #$type->name,
            AL_ID    , $type->annotationtype_id,
            AL_COLOR , $color
        );
        my @values = split /\s*\|\s*/, $type->values;
        foreach my $value ( @values ) {
            my $value_iter = $store->append( $child_iter );
            $store->set( $value_iter, AL_NAME, $value );
        }
    }
    $self->annotation_list->expand_to_path( $store->get_path( $iter ) );
}

sub _build_add_annotationset_button {
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

has 'message_annotations' => (
    is => 'ro',
    isa => 'Gtk2::TreeModel',
    lazy_build => 1,
);

sub _build_message_annotations {
    my $store = Gtk2::ListStore->new( qw/ Glib::Int Glib::Int Glib::String Glib::String Glib::String Glib::Int / );
    $store->set_sort_column_id( MA_START, 'ascending' );
    return $store;
}

has 'message_annotations_view' => (
    is => 'ro',
    isa => 'Gtk2::TreeView',
    lazy_build => 1,
);

sub _build_message_annotations_view {
    my $self = shift;
    my $view = Gtk2::TreeView->new( $self->message_annotations );

    my ( $start_renderer, $end_renderer, $name_renderer, $value_renderer )
        = map { Gtk2::CellRendererText->new } 1..4;

    my $name_column = Gtk2::TreeViewColumn->new_with_attributes( "Name", $name_renderer, text => MA_NAME );
    $name_column->set_expand( TRUE );
    $view->append_column( $name_column );

    my $value_column = Gtk2::TreeViewColumn->new_with_attributes( "Value", $value_renderer, text => MA_VALUE );
    $value_column->set_expand( TRUE );
    $view->append_column( $value_column );

    my $start_column = Gtk2::TreeViewColumn->new_with_attributes( "Start", $start_renderer, text => MA_START );
    #$start_column->set_expand( TRUE );
    $view->append_column( $start_column );

    my $end_column = Gtk2::TreeViewColumn->new_with_attributes( "End", $end_renderer, text => MA_END );
    #$end_column->set_expand( TRUE );
    $view->append_column( $end_column );

    return $view;
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
    $annotation_panel->pack_end( $self->message_annotations_view, TRUE, TRUE, 0 );
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


