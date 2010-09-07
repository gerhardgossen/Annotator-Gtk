package Annotator::Gtk::View::MessageList;

use Moose;
use MooseX::NonMoose;
use MooseX::Types::Moose qw( CodeRef );
use Gtk2;
use Annotator::Gtk::View::Constants qw( :bool );

extends 'Gtk2::TreeView';

sub FOREIGNBUILDARGS { () }

has '_list_store' => (
    is => 'ro',
    isa => 'Gtk2::TreeModel',
    lazy_build => 1,
);

sub _build__list_store {
    Gtk2::ListStore->new( qw/ Glib::String Glib::String Glib::String / );
}

sub BUILD {
    my $self = shift;
    $self->set_model( $self->_list_store );

    my $subject_column = Gtk2::TreeViewColumn->new();
    $subject_column->set_title("Subject");
    $subject_column->set_expand( TRUE );
    my $subject_renderer = Gtk2::CellRendererText->new;
    $subject_column->pack_start( $subject_renderer, FALSE );
    $subject_column->add_attribute( $subject_renderer, text => 0 );
    $self->append_column($subject_column);

    my $date_column = Gtk2::TreeViewColumn->new();
    $date_column->set_title("Sent");
    $subject_column->set_max_width( 100 );
    my $date_renderer = Gtk2::CellRendererText->new;
    $date_column->pack_start( $date_renderer, FALSE );
    $date_column->add_attribute( $date_renderer, text => 1 );
    $self->append_column($date_column);

    $self->set_size_request( -1, 100 );

    $self->signal_connect( 'row-activated' => sub { $self->_on_message_selected( @_ ) } );
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

has 'current_messages' => (
    is => 'rw',
    trigger => \&_populate_message_list,
);

sub _populate_message_list {
    my ( $self, $msg_cursor ) = @_;
    my $model = $self->_list_store;
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
}

__PACKAGE__->meta->make_immutable;

1;
