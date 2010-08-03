package Annotator::Schema::Result::Text;

use parent qw/DBIx::Class::Core/;
use warnings;
use strict;

__PACKAGE__->load_components( qw( Core ) );
__PACKAGE__->table( 'text' );

__PACKAGE__->add_columns(
    text_id => {
        data_type => 'varchar',
        is_nullable => 0,
    },
    metadata => {
        data_type => 'text',
        is_nullable => 1,
    },
    contents => {
        data_type => 'text',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key( 'text_id' );
__PACKAGE__->has_many( documents => 'Annotator::Schema::Result::Document', 'text_id' );
__PACKAGE__->has_many( annotations => 'Annotator::Schema::Result::Annotation', 'text_id' );

1;