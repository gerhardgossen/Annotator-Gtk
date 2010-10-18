package Annotator::Schema::Result::Document;

use parent qw/DBIx::Class::Core/;

__PACKAGE__->load_components( qw( Helper::Row::ToJSON InflateColumn::DateTime Core ) );
__PACKAGE__->table( 'document' );

__PACKAGE__->add_columns(
    document_id => {
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    path => {
        data_type => 'varchar',
        is_nullable => 0,
    },
    title => {
        data_type => 'varchar',
        is_nullable => 1,
    },
    date => {
        data_type => 'datetime',
        is_nullable => 1,
        is_serializable => 1,
    },
    sender => {
        data_type => 'varchar',
        is_nullable => 1,
    },
    text_id => {
        data_type => 'varchar',
        is_foreign_key => 1,
    }
);

__PACKAGE__->set_primary_key('document_id');
__PACKAGE__->belongs_to( text => 'Annotator::Schema::Result::Text', 'text_id' );

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index( fields => ['path'] );
}

#use Annotator::DateTime;
#
#sub _inflate_to_datetime {
#   my $self = shift;
#   my $val = $self->next::method(@_);
#
#   return bless $val, 'Annotator::DateTime';
#}

1;
