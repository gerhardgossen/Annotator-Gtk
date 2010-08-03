package Annotator::Schema;

use strict;
use warnings;
our $VERSION = 0.001;

use parent qw/DBIx::Class::Schema/;

__PACKAGE__->load_namespaces();

1;
