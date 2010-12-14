# See bottom of file for license and copyright information

package UpdateAttachmentsPluginTests;

use strict;
use warnings;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );
use Error ':try';

use Unit::Request;
use Unit::Response;
use Foswiki;
use Foswiki::UI::Save;
use Foswiki::Plugins::UpdateAttachmentsPlugin;
use CGI;
use File::Path qw(mkpath);

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $this->{attach_web}   = "$this->{test_web}Attach";
    my $webObject = Foswiki::Meta->new( $this->{session}, $this->{attach_web} );
    $webObject->populateNewWeb();

#    Foswiki::Func::getContext()->{view} = 1;
    $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{Debug} = 0;
    $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{Module} = 'Foswiki::Plugins::UpdateAttachmentsPlugin';
    $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser} = '';
    $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{RemoveMissing} = 1;
    $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{CheckUPDATEATACHPermission} = 1;

    $this->{tmpdatafile8}  = $Foswiki::cfg{TempfileDir} . '/eight.bytes';
    $this->{tmpdatafile16}  = $Foswiki::cfg{TempfileDir} . '/sixteen.bytes';
    $this->{tmpdatafile32}  = $Foswiki::cfg{TempfileDir} . '/thirtytwo.bytes';
    $this->{tmpdatafilex}  = $Foswiki::cfg{TempfileDir} . '/bad # file @ name';

    return;
}

sub tear_down {
    my $this = shift;
    $this->removeWeb( $this->{attach_web} );

    unlink $this->{tmpdatafile8};
    unlink $this->{tmpdatafile16};
    unlink $this->{tmpdatafile32};
    unlink $this->{tmpdatafilex};

    $this->SUPER::tear_down();

    return;
}

# Save a topic into the web.
sub _writeTopic {
    my ( $this, $web, $topic, $text ) = @_;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, $text );
    $meta->save();

    return;
}

# Save an attachment into the web/topic
sub _writeFile {
    my ($web, $topic, $attach, $content) = @_;

    $content = "datadata/n" unless ($content);

    my $path = "$Foswiki::cfg{PubDir}/$web/$topic";

    mkpath($path);
    open( my $fh, '>', "$path/$attach" )
      or die "Unable to open $path/$attach for writing: $!\n";
    print $fh "$content \n";
    close($fh);
    return;
}

# Attach a file to the web/topic
sub _attachFile {
    my ( $this, $web, $topic, $file, $text ) = @_;

    return;
}

sub _trim {
    my $s = shift;
    $s =~ s/^\s*(.*?)\s*$/$1/sgo;
    return $s;
}


# Not a test, a helper.
sub runREST {
    my ( $this, $web, $topic ) = @_;

    $web   ||= $this->{attach_web};
    $topic ||= 'WebHome';

    my $url = Foswiki::Func::getScriptUrl( 'UpdateAttachmentsPlugin', 'update', 'rest' );


    # Compose the query
    my $query = Unit::Request->new(
        {
            'topic'          => "$web.$topic",
        }
    );
    $query->path_info("/UpdateAttachmentsPlugin/update");

    my $session = Foswiki->new( $Foswiki::cfg{DefaultUserLogin}, $query );
    my $text = "Ignore this text";

    # invoke the save handler
    my ($resp) = $this->captureWithKey( rest => $this->getUIFn('rest'), $session );

    print STDERR "RESPONSE:  $resp";

}

sub test_SimpleRest {
    my $this = shift;

    my $web = $this->{attach_web};

    _writeTopic( $this, $web, 'AnotherTopic', <<HERE );
Topic Text
HERE

    _writeFile( $web, 'AnotherTopic', 'SomeFile');  

    $this->runREST( undef, undef);
    $this->runREST( undef, undef);

    return;
}




1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
