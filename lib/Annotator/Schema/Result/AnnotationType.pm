package Annotator::Schema::Result::AnnotationType;

use parent qw/ DBIx::Class::Core /;

__PACKAGE__->load_components( qw( Core ) );
__PACKAGE__->table( 'annotationtype' );

__PACKAGE__->add_columns(
    annotationtype_id => {
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    name => {
        data_type => 'varchar',
        is_nullable => 0,
    },
    values => {
        data_type => 'varchar',
        is_nullable => 0,
    },
    is_tag => {
        data_type => 'boolean',
    },
    annotationset_id => {
        data_type => 'integer',
        is_nullable => 0,
        is_foreign_key => 0,
    },
);

__PACKAGE__->set_primary_key( 'annotationtype_id' );
__PACKAGE__->belongs_to( annotationset => 'Annotator::Schema::Result::AnnotationSet', 'annotationset_id' );
__PACKAGE__->has_many( annotations => 'Annotator::Schema::Result::Annotation', 'annotationtype_id' );

1;
