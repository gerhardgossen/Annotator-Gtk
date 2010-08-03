package Annotator::Schema::Result::Annotator;

use parent qw/ DBIx::Class::Core /;

__PACKAGE__->load_components( qw( Helper::Row::ToJSON Core ) );
__PACKAGE__->table( 'annotator' );

__PACKAGE__->add_columns(
    annotator_id => {
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    name => {
        data_type => 'varchar',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key( 'annotator_id' );
__PACKAGE__->has_many( annotationsets => 'Annotator::Schema::Result::AnnotationSet', 'creator_id' );
__PACKAGE__->has_many( annotations => 'Annotator::Schema::Result::Annotation', 'creator_id' );

1;
