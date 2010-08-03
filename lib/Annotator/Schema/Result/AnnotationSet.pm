package Annotator::Schema::Result::AnnotationSet;

use parent qw/ DBIx::Class::Core /;

__PACKAGE__->load_components( qw( Core ) );
__PACKAGE__->table( 'annotationset' );

__PACKAGE__->add_columns(
    annotationset_id => {
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    name => {
        data_type => 'varchar',
        is_nullable => 0,
    },
    creator_id => {
        data_type => 'integer',
        is_nullable => 0,
        is_foreign_key => 1,
    },
    description => {
        data_type => 'text'
    },
);

__PACKAGE__->set_primary_key( 'annotationset_id' );
__PACKAGE__->belongs_to( creator => 'Annotator::Schema::Result::Annotator', 'creator_id' );
__PACKAGE__->has_many( annotation_types => 'Annotator::Schema::Result::AnnotationType', 'annotationset_id' );

1;