package Annotator::Gtk::View::MessageList;

use Moose;
use MooseX::NonMoose;
use MooseX::Types::Moose qw( CodeRef );
use Gtk2;
use Annotator::Gtk::View::Constants qw( :bool );

use constant {
    ML_TITLE   => 0,
    ML_DATE    => 1,
    ML_TEXT_ID => 2,
    ML_SENDER  => 3,
};

extends 'Gtk2::TreeView';

sub FOREIGNBUILDARGS { () }

has '_list_store' => (
    is => 'ro',
    isa => 'Gtk2::TreeModel',
    lazy_build => 1,
);

sub _build__list_store {
    Gtk2::ListStore->new( qw/ Glib::String Glib::String Glib::String Glib::Boolean / );
}

sub BUILD {
    my $self = shift;
    $self->set_model( $self->_list_store );
    $self->set_fixed_height_mode( TRUE );

    my $subject_column = Gtk2::TreeViewColumn->new();
    $subject_column->set_title("Subject");
    $subject_column->set_expand( TRUE );
    $subject_column->set_sizing( 'fixed' );
    my $subject_renderer = Gtk2::CellRendererText->new;
    $subject_column->pack_start( $subject_renderer, FALSE );
    $subject_column->add_attribute( $subject_renderer, text => ML_TITLE );
    $self->append_column($subject_column);

    my $date_column = Gtk2::TreeViewColumn->new();
    $date_column->set_title("Sent");
    $date_column->set_fixed_width( 100 );
    $date_column->set_sizing( 'fixed' );
    my $date_renderer = Gtk2::CellRendererText->new;
    $date_column->pack_start( $date_renderer, FALSE );
    $date_column->add_attribute( $date_renderer, text => ML_DATE );
    $self->append_column($date_column);

    my $sender_column = Gtk2::TreeViewColumn->new();
    $sender_column->set_title("Out?");
    $sender_column->set_sizing( 'fixed' );
    $sender_column->set_fixed_width( 20 );
    my $sender_renderer = Gtk2::CellRendererToggle->new;
    $sender_column->pack_start( $sender_renderer, FALSE );
    $sender_column->add_attribute( $sender_renderer, active => ML_SENDER );
    $self->append_column($sender_column);

    $self->set_size_request( -1, 100 );

    $self->signal_connect( 'row-activated' => sub { $self->_on_message_selected( @_ ) } );
}

sub _on_message_selected {
    my ( $self, $message_list, $path ) = @_;
    my $iter = $message_list->get_model->get_iter( $path );
    my $mid = $message_list->get_model->get( $iter, ML_TEXT_ID );
    $self->on_message_selected->( $mid );
}

has 'on_message_selected' => (
    is => 'rw',
    isa => CodeRef,
    default => sub { sub { } },
);

has 'get_current_user' => (
    is => 'ro',
    isa => CodeRef,
    required => 1,
);

has 'current_messages' => (
    is => 'rw',
    trigger => \&_populate_message_list,
);

sub select_message{
    my ( $self, $text_id ) = @_;

    my $model = $self->get_model;
    my $iter = $model->get_iter_first;

    while ( $iter ) {
        last if $model->get( $iter, ML_TEXT_ID ) eq $text_id;

        $iter = $model->iter_next( $iter );
    }

    die "Message '$text_id' does not exist" unless $iter;

    my $treepath = $model->get_path( $iter );
    $self->scroll_to_cell( $treepath, undef, TRUE, 0.5, 0.0 );
    $self->set_cursor( $treepath, undef, FALSE );
    $self->_on_message_selected( $self, $treepath );
}

use List::Util 'first';

sub _populate_message_list {
    my ( $self, $msg_cursor ) = @_;
    my $model = $self->_list_store;
    $model->clear;

    $msg_cursor->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my ( $username ) = ( $self->get_current_user->() =~ /^(\w+)-/ );
    my $re = qr/\b$username\b/io;
    while ( my $message = $msg_cursor->next ) {
        my $iter = $model->append;
        $model->set(
            $iter,
            ML_TITLE,   $message->{title},
            ML_DATE,    $message->{date},
            ML_TEXT_ID, $message->{text_id},
            ML_SENDER,  ( $message->{sender} =~ $re ? TRUE : FALSE ) 
        );
    }
}

__PACKAGE__->meta->make_immutable;

1;
