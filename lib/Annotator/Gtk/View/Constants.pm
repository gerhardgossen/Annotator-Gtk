package Annotator::Gtk::View::Constants;

use parent 'Exporter';

use constant {
    TRUE  => 1,
    FALSE => 0,
};

use constant {
    AL_NAME  => 0,
    AL_ID    => 1,
    AL_COLOR => 2,
};

use constant {
    MA_START => 0,
    MA_END   => 1,
    MA_NAME  => 2,
    MA_VALUE => 3,
    MA_ID    => 4,
    MA_ANNID => 5,
};


our @EXPORT = ();
our @EXPORT_OK = qw( );
our %EXPORT_TAGS = (
    bool => [ qw( TRUE FALSE ) ],
    annotations => [ qw( AL_NAME AL_ID AL_COLOR ) ],
    message_annotations => [ qw( MA_START MA_END MA_NAME MA_VALUE MA_ID MA_ANNID ) ]
);

Exporter::export_ok_tags( $_ ) foreach qw( bool annotations message_annotations );

1;
