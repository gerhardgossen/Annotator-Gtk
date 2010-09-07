package Annotator::Gtk::View::AnnotationsEditor;

use Moose;
use MooseX::NonMoose;
use MooseX::Types::Moose qw( ArrayRef Int Maybe );
use Gtk2;

use Annotator::Gtk::View::Constants qw( :bool :annotations :message_annotations );

extends 'Gtk2::Window';

sub FOREIGNBUILDARGS { 'popup' } # args for superclass constructor

sub BUILD {
    my $self = shift;
    my $vbox = Gtk2::VBox->new;
    $self->add( $vbox );
    my $layout = Gtk2::Table->new( 1, 3, FALSE );
    $layout->set_name( 'annotations_container' );
    $vbox->pack_start( $layout, FALSE, TRUE, 0 );
    $self->_add_annotation_row( $layout, $self->_next_row_id );

    my $hb_wrapper = Gtk2::HBox->new;
    $hb_wrapper->pack_start( $self->_add_row_button, FALSE, FALSE, 6 );

    my $hide_overlay = Gtk2::Button->new("Hide");
    $hide_overlay->signal_connect( clicked => sub { $self->hide } );
    $hb_wrapper->pack_end( $hide_overlay, FALSE, FALSE, 6 );
    $vbox->pack_end( $hb_wrapper, FALSE, FALSE, 0 );
    $vbox->show_all;
}

has [qw/ start end /] => (
    is => 'rw',
    isa => Maybe[Int],
);

has 'annotations' => (
    is => 'rw',
    isa => ArrayRef[ 'Gtk2::TreeModelIter' ],
    traits => [ 'Array' ],
    handles => {
        remove_annotation => 'delete',
    },
);

has [ qw/ annotations_only_model / ]  => (
    is => 'ro',
    isa => 'Gtk2::TreeModel',
    required => 1,
);

has 'mutation_handler' => (
    is => 'ro',
    does => 'Annotator::Gtk::View::AnnotationMutationHandler',
    required => 1,
);

has message_annotations => (
    is => 'ro',
    isa => 'Annotator::Gtk::View::MessageAnnotations',
    required => 1,
);

has _row_count => ( # TODO: replace by |$self->annotations|
    traits => [ 'Counter' ],
    is => 'rw',
    isa => Int,
    default => -1,
    handles => {
        _next_row_id => 'inc',
    },
);

has _add_row_button => (
    is => 'ro',
    isa => 'Gtk2::Button',
    lazy_build => 1,
);

sub _build__add_row_button {
    my $self = shift;
    my $add_row = Gtk2::Button->new_from_stock( 'gtk-add' );
    $add_row->signal_connect( clicked => sub {
        $self->_add_annotation_row( $self->_get_annotations_table, $self->_next_row_id );
    } );
    $add_row
}

sub _add_annotation_row {
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
            $value_box->set_model( Gtk2::TreeModelFilter->new( $self->annotations_only_model->get_model, $path ) );
        }
    } );
    $value_box->signal_connect( changed => sub {
        my $box = shift;
        my ( $row ) = ( $box->get_name =~ /^value_(\d+)$/ );
        my $filtered_model = $box->get_model;
        my $filtered_value_iter = $box->get_active_iter;
        return unless $filtered_value_iter;
        my $value_iter = $filtered_model->convert_iter_to_child_iter( $filtered_value_iter );
        my $annotationtype_id = _get_combo_value( $annotation_box, AL_ID );
        my $value = $filtered_model->get_model->get( $value_iter, AL_NAME );
        my $iter = $self->annotations->[ $row ];
        if ( defined $iter ) {
            $self->mutation_handler->annotation_changed(
                $iter,
                $self->message_annotations->model->get( $iter, MA_ID ),
                $annotationtype_id,
                $value,
                $self->message_annotations->model->get( $iter, MA_START ),
                $self->message_annotations->model->get( $iter, MA_END   ),
            );
        } else {
            my $iter = $self->mutation_handler->annotation_added(
                undef,
                $annotationtype_id,
                $value,
                $self->start,
                $self->end
            );
            $self->annotations->[ $row ] = $iter;
        }
    } );

    my $remove = Gtk2::Button->new;
    $remove->set_image( Gtk2::Image->new_from_stock( 'gtk-remove', 'button' ) );
    $remove->set_name( "remove_$row" );
    $remove->signal_connect( clicked => sub { $self->_remove_annotation_row( $row ) } );

    $layout->attach( $annotation_box, 0, 1, $row, $row + 1, $opts, $opts, $padding, $padding );
    $layout->attach( $value_box, 1, 2, $row, $row + 1, $opts, $opts, $padding, $padding );
    $layout->attach( $remove, 2, 3, $row, $row + 1, $opts, $opts, $padding, $padding );

    $layout->show_all;
}

sub _remove_annotation_row {
    my ( $self, $row ) = @_;
    my $table = $self->_get_annotations_table;
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
    $self->_row_count( $self->_row_count - 1);
    if ( $table->get( 'n-rows' ) == 1 ) {
        $self->_add_annotation_row( $self->_get_annotations_table, $self->_next_row_id );
    } else {
        $table->resize( $table->get( 'n-rows' ) - 1, $table->get( 'n-columns' ) );
    }
    $table->show_all;

    $self->mutation_handler->annotation_removed( $self->annotations->[ $row ] );
    splice @{ $self->annotations }, $row, 1;
}

sub show {
    my ( $self, %args ) = @_;

    $self->start( $args{start} );
    $self->end(   $args{end}   );
    $self->annotations( $args{annotations} || [] );
    # Only enable new annotations if selection is given
    $self->_add_row_button->set_sensitive( defined $self->start && defined $self->end );

    $self->next::method;
    $self->move( $args{x}, $args{y} );

}

sub reset {
    my $self = shift;
    if ( $self->_row_count < 0 ) {
       $self->_add_annotation_row( $self->_get_annotations_table, $self->_next_row_id );
    } else {
        while ( $self->_row_count > 0 ) {
            $self->_remove_annotation_row( $self->_row_count );
        }
        my $table = $self->_get_annotations_table;
        foreach my $widget ( $table->get_children ) {
            if ( $widget->isa( 'Gtk2::ComboBox' ) ) {
                $widget->set_active( -1 );
            }
        }
    }
}

sub hide {
    my $self = shift;
    return unless $self->get( 'visible' );

    $self->next::method;
    $self->reset;
}

sub _get_combo_value {
    my ( $box, $col ) = @_;
    my $iter = $box->get_active_iter;
    return $iter ? $box->get_model->get( $iter, $col ) : undef;
}

sub _get_annotations_table {
    my $self = shift;
    my $container = ( ( $self->get_children )[0]->get_children )[0];
    unless ( $container->get_name eq 'annotations_container' ) {
        die 'Widget hierarchy is wrong, expected annotations_container';
    }
    return $container;
}

__PACKAGE__->meta->make_immutable;

1;
