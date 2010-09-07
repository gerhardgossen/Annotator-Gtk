use strict;
use warnings;
package Annotator::Gtk::View;

use feature 'say', 'switch';

use utf8;
use Gtk2 '-init';
use Moose;
use MooseX::NonMoose;
use MooseX::Types::Moose qw( ArrayRef CodeRef HashRef Int Str );
use Annotator::Gtk::View::AnnotationsEditor;
use Annotator::Gtk::View::AnnotationSetEditor;
use Annotator::Gtk::View::AnnotationSetList;
use Annotator::Gtk::View::FolderTree;
use Annotator::Gtk::View::MessageAnnotations;
use Annotator::Gtk::View::MessageList;
use Annotator::Gtk::View::Constants qw( :bool :annotations :message_annotations );

use namespace::autoclean;

extends 'Gtk2::Window';
with 'Annotator::Gtk::View::AnnotationMutationHandler';

sub FOREIGNBUILDARGS { () }

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
    $self->add_accel_group($accelgroup);

    my $actions_basic = Gtk2::ActionGroup->new ("actions_basic");
    $actions_basic->add_actions (\@actions_plain, undef);

    $uimanager->insert_action_group($actions_basic,0);

    $uimanager->add_ui_from_string ($ui_basic);

    return $uimanager->get_widget('/MenuBar');
}

has 'overlay' => (
    is => 'ro',
    isa => 'Annotator::Gtk::View::AnnotationsEditor',
    lazy_build => 1,
);

sub _build_overlay {
    my $self = shift;
    my $overlay = Annotator::Gtk::View::AnnotationsEditor->new(
        message_annotations    => $self->message_annotations,
        annotations_only_model => $self->annotations_only_model,
        mutation_handler       => $self->message_annotations,
    );
    $overlay
}

sub annotation_added {
    my ( $self, $annotation_id, $annotationtype_id, $value, $start, $end ) = @_;

    $self->highlight_annotation( $annotationtype_id, $start, $end );
}

sub annotation_changed {
    my ( $self, $iter, $annotation_id, $annotationtype_id, $value, $start, $end ) = @_;
    my $model = $self->message_annotations->model;
    $self->unhighlight_annotation( map { $model->get( $iter, $_ ) } ( MA_ANNID, MA_START, MA_END ) );

    $self->highlight_annotation( $annotationtype_id, $start, $end );
}

sub annotation_removed {
    my ( $self, $iter ) = @_;
    my $model = $self->message_annotations->model;
    $self->unhighlight_annotation( map { $model->get( $iter, $_ ) } ( MA_ANNID, MA_START, MA_END ) );
}

sub _wrap_in_scrolled_window {
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

    $self->add_events( [ 'button-release-mask', 'button-press-mask' ] );
    $textview->signal_connect( 'button-release-event' => sub {
        my ( $widget, $e ) = @_;

        if ( ( $self->_get_buffer_selection )[0] ) {
            $self->on_messageview_select->( $self, $e );
        } else {
            my $buffer = $widget->get_buffer;
            my $insert_mark = $buffer->get_mark( 'insert' );
            my $offset = $buffer->get_iter_at_mark( $insert_mark )->get_offset;
            my @annotations = $self->find_annotations_at_offset( $offset );
            if ( @annotations ) {
                use Try::Tiny;
                try {
                $self->overlay->show( x => $e->x_root, y => $e->y_root, annotations => []#\@annotations
                 );
                } catch {
                    die $_;
                };
            }
        }
        return FALSE; # propagate event
    } );

    $textview->signal_connect( 'button-press-event' => sub {
        my ( $widget, $e ) = @_;
        $self->on_messageview_click->( $e );
        return FALSE; # propagate event
    } );

    return $textview;
}

sub find_annotations_at_offset {
    my ( $self, $offset ) = @_;

    my @annotations;

    my $annotation_model = $self->message_annotations->model;
    my $iter = $annotation_model->get_iter_first;

    while ( $iter ) {
        my ( $start, $end ) = map { $annotation_model->get( $iter, $_ ) } ( MA_START, MA_END );
        if ( $start <= $offset && $offset <= $end ) {
            my $annotation_id = $annotation_model->get( $iter, MA_ID );
            push @annotations, {
                $annotation_id ? ( annotation_id => $annotation_id ) : (),
                annotationtype_id => $annotation_model->get( $iter, MA_ANNID ),
                start             => $start,
                end               => $end,
                value             => $annotation_model->get( $iter, MA_VALUE ),
            };
        }

        $iter = $annotation_model->iter_next( $iter );
    }

    return @annotations;
}

=head2 on_messageview_mouse_release

Called with C<I<GdkEventButton> event>

=cut

has 'on_messageview_select' => (
    is => 'rw',
    isa => CodeRef,
    lazy_build => 1,
);

sub _build_on_messageview_select {
    return sub {
        my ( $self, $e ) = @_;
        my $buffer = $self->message_view->get_buffer;
        my ( $start_iter, $end_iter ) = $self->_get_buffer_selection;
        $self->overlay->show(
            x => $e->x_root,
            y => $e->y_root,
            start => $start_iter->get_offset,
            end => $end_iter->get_offset,
        );
        return FALSE;
    }
}

has 'on_messageview_click' => (
    is => 'rw',
    isa => CodeRef,
    default => sub { sub { } },
);

sub highlight_annotation {
    my ( $self, $annotationtype_id, $start, $end ) = @_;

    my $name = $self->annotation_sets->get_name_for_id( $annotationtype_id );
    my $tag = $self->annotation_sets->tag_for_annotation( $name );

    return unless $tag;

    my $buffer = $self->message_view->get_buffer;
    my $start_iter = $buffer->get_iter_at_offset( $start );
    my $end_iter = $buffer->get_iter_at_offset( $end );

    return unless $start_iter;

    $self->message_view->get_buffer->apply_tag( $tag, $start_iter, $end_iter );
}

sub unhighlight_annotation {
    my ( $self, $annotationtype_id, $start, $end ) = @_;

    my $name = $self->annotation_sets->get_name_for_id( $annotationtype_id );

    return unless $name;

    my $buffer = $self->message_view->get_buffer;
    my $start_iter = $buffer->get_iter_at_offset( $start );
    my $end_iter = $buffer->get_iter_at_offset( $end );

    return unless $start_iter;

    $buffer->remove_tag_by_name( $name, $start_iter, $end_iter );
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
    Annotator::Gtk::View::FolderTree->new(
        directories => $self->directories,
        on_folder_selected => sub {
            $self->on_folder_selected->( @_ )
        },
    );
}

has 'message_list' => (
    is => 'ro',
    isa => 'Annotator::Gtk::View::MessageList',
    lazy_build => 1,
);

sub _build_message_list {
    my $self = shift;
    return Annotator::Gtk::View::MessageList->new(
        on_message_selected => sub { $self->on_message_selected->( @_ ) },
    ); #TODO: cleanup?
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
    $self->message_annotations->load_message_annotations( $message );
    $self->push_status( "Loaded message '" . $message->text_id . "'." );
}

sub _save_message_annotations { # TODO: save changes immediately
    my ( $self, $message ) = @_;

    my $annotation_model = $self->message_annotations->model;

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

has 'annotation_model' => (
    is => 'ro',
    isa => 'Gtk2::TreeModel',
    lazy_build => 1,
);

sub _build_annotation_model {
    Gtk2::TreeStore->new( qw/ Glib::String Glib::UInt Glib::String / );
}

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

has 'model' => (
    is => 'rw',
    isa => 'Annotator::Schema',
    required => 1,
);

has 'on_folder_selected' => (
    is => 'rw',
    isa => CodeRef,
    default => sub { sub {} },
);

has 'annotation_sets' => (
    is => 'ro',
    isa => 'Annotator::Gtk::View::AnnotationSetList',
    lazy_build => 1,
);

sub _build_annotation_sets {
    my $self = shift;
    return Annotator::Gtk::View::AnnotationSetList->new(
        annotation_model    => $self->annotations_only_model,
        message_buffer      => $self->message_view->get_buffer,
        get_annotation_sets => sub {
            $self->model->resultset('AnnotationSet')->search_rs
        },
        get_annotation_set  => sub {
            $self->model->resultset('AnnotationSet')->find( shift )
        },
    );
}

has 'message_annotations' => (
    is => 'ro',
    isa => 'Annotator::Gtk::View::MessageAnnotations',
    lazy_build => 1,
);

sub _build_message_annotations {
    my $self = shift;
    my $ma = Annotator::Gtk::View::MessageAnnotations->new(
        annotation_sets => $self->annotation_sets,
    );
    $ma->add_mutation_listener( $self );
    return $ma;
}

sub BUILD {
    my $self = shift;

    $self->set_title ( $self->window_title );
    $self->set_border_width(0);
    $self->signal_connect( destroy => sub { Gtk2->main_quit; } );

    my $vbox = Gtk2::VBox->new(FALSE, 0);
    $self->add($vbox);

    my $content_box = Gtk2::HPaned->new;
    $content_box->pack1( _wrap_in_scrolled_window( $self->foldertree ), FALSE, TRUE );
    my $rhs = Gtk2::HPaned->new;
    my $middle_panel = Gtk2::VBox->new;
    $rhs->pack1( $middle_panel, TRUE, TRUE );
    $middle_panel->pack_start( _wrap_in_scrolled_window( $self->message_list ), TRUE, TRUE, 0 );
    $middle_panel->pack_start( _wrap_in_scrolled_window( $self->message_view ), TRUE, TRUE, 0);
    $content_box->pack2( $rhs, TRUE, TRUE );

    my $rhs_panel = Gtk2::VBox->new;
    $rhs_panel->pack_start( $self->annotation_sets, TRUE, TRUE, 0 );
    $rhs_panel->pack_end( $self->message_annotations, TRUE, TRUE, 0 );
    $rhs->pack2( $rhs_panel, TRUE, TRUE );

    $vbox->pack_start( $self->menubar, FALSE, FALSE, 0 );
    $vbox->pack_start( $content_box, TRUE, TRUE, 0 );

    $vbox->pack_end( $self->_statusbar, FALSE, FALSE, 0 );
}

sub show {
    my $self = shift;

    $self->show_all;
    Gtk2->main;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
