package Annotator::Schema::ResultSet::Document;

use Moose;
extends 'DBIx::Class::ResultSet';

has directories => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
);

sub _build_directories {
    my $self = shift;
    my $dirs = $self->search( undef, {
        select => [ 'path', { count => 'path', -as => 'num_children' }  ],
        as => [ 'path', 'num_children' ],
        group_by => [ 'path' ],
        order_by => [ 'path' ],
    });
    my $tree = {};
    use Devel::Dwarn;
    while ( my $dir = $dirs->next ) {
        my @nameparts = split qr|/|, $dir->path;
        my $pos = $tree;
        foreach my $namepart ( @nameparts ) {
            if ( $namepart eq $nameparts[-1] ) {
                $pos->{ $namepart }->{count} = $dir->get_column( 'num_children' );
            } else {
                $pos->{ $namepart }->{children} = {}
                    unless defined $pos->{ $namepart }
                        && defined $pos->{ $namepart }->{children};
                $pos->{ $namepart }->{count} += $dir->get_column( 'num_children' );
                $pos = $pos->{ $namepart }->{children};
            }
        }
    }
    return $tree;
}

sub get_sub_directories { # TODO: bug assigns wrong count to top-level directories
    my ( $self, $path ) = @_;
    if ( ! defined $path || $path eq '/') {
        return [ sort map { "/$_\t" . $self->directories->{ $_ }->{count} } keys %{ $self->directories } ];
    }

    my @nameparts = split qr|/|, $path;
    shift @nameparts;
    my $pos = $self->directories;
    foreach my $part ( @nameparts ) {
        if ( defined $pos->{ $part } && defined $pos->{ $part }->{children} ) {
            $pos = $pos->{ $part }->{children};
        } else {
            return undef;
        }
    }
    return [ sort map { "$path/$_\t" . $pos->{$_}->{count} } keys %{ $pos } ];
}

sub get_folder_messages {
    my ( $self, $path ) = @_;
    return $self->search_rs( { path => $path } );
}

1;
