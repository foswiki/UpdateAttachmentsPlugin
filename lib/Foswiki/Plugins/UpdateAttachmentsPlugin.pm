package Foswiki::Plugins::UpdateAttachmentsPlugin;
use strict;
use warnings;

use Foswiki::Plugins ();
use Foswiki::Func    ();

our $VERSION = '3.13';
our $RELEASE = '3.13';
our $SHORTDESCRIPTION =
  'A batched alternative to Auto Attachments (adds and removes attachements).';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

sub core {

    unless ( defined $core ) {
        require Foswiki::Plugins::UpdateAttachmentsPlugin::Core;
        $core = Foswiki::Plugins::UpdateAttachmentsPlugin::Core->new();
    }

    return $core;
}

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between UpdateAttachmentsPlugin  and Plugins.pm");
        return 0;
    }

    Foswiki::Func::registerRESTHandler(
        'update', sub { core->restUpdate(@_) },
        authenticate => 1,
        validate     => 0,
        http_allow   => 'GET,POST',
    );

    #force autoattach off
    $Foswiki::cfg{AutoAttachPubFiles} = 0;         # Foswiki 1.x
    $Foswiki::cfg{RCS}{AutoAttachPubFiles} = 0;    # Foswiki 2.x

    return 1;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2007-2012 SvenDowideit@fosiki.com

Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2001-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

