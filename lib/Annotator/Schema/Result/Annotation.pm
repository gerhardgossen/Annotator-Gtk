package Annotator::Schema::Result::Annotation;

use parent qw/ DBIx::Class::Core /;

__PACKAGE__->load_components( qw( TimeStamp InflateColumn::DateTime Core ) );
__PACKAGE__->table( 'annotation' );

__PACKAGE__->add_columns(
    annotation_id => {
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    text_id => {
        data_type => 'varchar',
        is_nullable => 0,
        is_foreign_key => 1,
    },
    annotationtype_id => {
        data_type => 'integer',
        is_nullable => 0,
        is_foreign_key => 1,
    },
    creator_id => {
        data_type => 'integer',
        is_nullable => 0,
        is_foreign_key,
    },
    start => {
        data_type => 'integer',
        is_nullable => 1,
    },
    end => {
        data_type => 'integer',
        is_nullable => 1,
    },
    value => {
        data_type => 'varchar',
        is_nullable => 1,
    },
    created => {
        data_type => 'datetime',
        set_on_create => 1,
    },
);

__PACKAGE__->set_primary_key( 'annotation_id' );
__PACKAGE__->belongs_to( text => 'Annotator::Schema::Result::Text', 'text_id' );
__PACKAGE__->belongs_to( annotation_type => 'Annotator::Schema::Result::AnnotationType', 'annotationtype_id' );
__PACKAGE__->belongs_to( creator => 'Annotator::Schema::Result::Annotator', 'creator_id' );