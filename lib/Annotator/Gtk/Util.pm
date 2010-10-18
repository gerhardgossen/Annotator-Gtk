package Annotator::Gtk::Util;

use Email::Simple;
use Mail::Address;

sub get_addresses_from_fields {
    my ( $header, @fieldnames ) = @_;
    my $email = Email::Simple->new( $header );
    return map { [ Mail::Address->parse( $email->header( $_ ) ) ] } @fieldnames;
}

1;
