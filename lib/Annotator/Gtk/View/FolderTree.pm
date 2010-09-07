package Annotator::Gtk::View::FolderTree;

use Moose;
use MooseX::NonMoose;
use MooseX::Types::Moose qw( CodeRef HashRef );
use Annotator::Gtk::View::Constants qw( :bool );
use Gtk2;

extends 'Gtk2::TreeView';

sub FOREIGNBUILDARGS { () }

has 'on_folder_selected' => (
    is => 'ro',
    isa => CodeRef,
    required => 1,
);

has 'directories' => (
    is => 'ro',
    required => 1,
    isa => HashRef[ HashRef ],
);

has '_folder_store' => (
    is => 'ro',
    isa => 'Gtk2::TreeModel',
    lazy_build => 1,
);

sub _build__folder_store {
    Gtk2::TreeStore->new( qw/ Glib::String Glib::UInt / )
}

sub BUILD {
    my $self = shift;

    $self->set_model( $self->_folder_store );

    _folder_tree_append_nodes( $self->_folder_store, undef, $self->directories );

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
    $self->append_column($path_column);

    my $number_column = Gtk2::TreeViewColumn->new();
    $number_column->set_title("#Msgs");
    $number_column->set_expand( FALSE );
    my $number_renderer = Gtk2::CellRendererText->new;
    $number_column->pack_start( $number_renderer, FALSE );
    $number_column->add_attribute( $number_renderer, text => 1 );
    $self->append_column($number_column);

    $self->set_search_column(0);
    $self->set_reorderable(FALSE);
    $self->set_size_request( 240, -1 );


    $self->signal_connect( 'row-activated' => sub { $self->_on_folder_tree_selected( @_ ) } );
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
    #$self->push_status( "Loading folder '$folder'" );
    $self->on_folder_selected->( $folder );
}

__PACKAGE__->meta->make_immutable;

1;
