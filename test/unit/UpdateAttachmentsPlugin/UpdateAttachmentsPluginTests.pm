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
    my ( $web, $topic, $attach, $content ) = @_;
    $content = "datadata/n" unless ($content);

    my $path = $Foswiki::cfg{TempfileDir};
    open( my $fh, '>', "$path/$attach" )
      or die "Unable to open $path/$attach for writing: $!\n";
    print $fh "$content \n";
    close($fh);

    Foswiki::Func::saveAttachment( $web, $topic, $attach,
                                    { file => "$path/$attach", 
                                      comment => 'Picture of Health',
                                      hide => 1 } );
}

sub _trim {
    my $s = shift;
    $s =~ s/^\s*(.*?)\s*$/$1/sgo;
    return $s;
}


# Not a test, a helper.
sub runREST {
    my ( $this, $topic ) = @_;

    my $web   = $this->{attach_web};
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

    #print STDERR "RESPONSE:  $resp";
    return $resp;

}

#
#   Verify that a file is attached on the first run
#   and is not attached on a 2nd run.
#
sub test_SimpleAttachment {
    my $this = shift;

    my $web = $this->{attach_web};

    _writeTopic( $this, $web, 'AnotherTopic', <<HERE );
Topic Text
HERE

    _writeFile( $web, 'AnotherTopic', 'SomeFile');

    # first run - attach one file.

    my $resp = $this->runREST( 'WebHome' );

    my $match = <<"HERE";
Attachments updated 0, added 1, removed 0, ignored 0 <br/><br/>
Updating $web.AnotherTopic <br/>
Added SomeFile <br/>
HERE

    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );

    $resp = $this->runREST( 'WebHome' );
    $match = <<"HERE";
Attachments updated 0, added 0, removed 0, ignored 0 <br/><br/>
HERE
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );
}

#
#   Verify removing all attachments
#
sub test_removeAllAttach {
    my $this = shift;

    my $web = $this->{attach_web};

    _writeTopic( $this, $web, 'AnotherTopic', <<HERE );
Topic Text
HERE

    _attachFile( $web, 'AnotherTopic', 'SomeFile');

    unlink  "$Foswiki::cfg{PubDir}/$web/AnotherTopic/SomeFile";

    my $resp = $this->runREST( 'WebHome' );

    my $match = <<"HERE";
Attachments updated 0, added 0, removed 1, ignored 0 <br/><br/>
Updating $web.AnotherTopic <br/>
Removed SomeFile <br/>
HERE

    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );

    # Run tes a 2nd time - nothing to remove.
    $resp = $this->runREST( 'WebHome' );

    $match = <<"HERE";
Attachments updated 0, added 0, removed 0, ignored 0 <br/><br/>
HERE

    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );

}

#
#   Verify that a bad attachment name is not attached,
#   and is reported as being ignored.
#
sub test_badAttachment {
    my $this = shift;

    my $web = $this->{attach_web};

    _writeTopic( $this, $web, 'AnotherTopic', <<HERE );
Topic Text
HERE

    _writeFile( $web, 'AnotherTopic', 'bad # file @ name');

    my $resp = $this->runREST( 'WebHome' );

    my $match = <<"HERE";
UpdateAttachments Topics checked 2, updated 0, <br/> 
Attachments updated 0, added 0, removed 0, ignored 1 <br/><br/>
AutoAttachPubFiles ignoring "bad # file @ name" in $web.AnotherTopic - not a valid Foswiki Attachment filename<br/>
HERE
    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );

}

#
#   Verify that a file is attached on the first run
#   and is not attached on a 2nd run.
#
sub test_verifyAttachMetadata {
    my $this = shift;

    my $web = $this->{attach_web};

    _writeTopic( $this, $web, 'AnotherTopic', <<HERE );
Topic Text
HERE

    _attachFile( $web, 'AnotherTopic', 'EightBytes', "88888888");
    _attachFile( $web, 'AnotherTopic', 'FourBytes', "4444");

    my ($meta, $text) = Foswiki::Func::readTopic( $web, 'AnotherTopic');
    return;


    my $resp = $this->runREST( 'WebHome' );

    my $match = <<"HERE";
Attachments updated 0, added 1, removed 0, ignored 0 <br/><br/>
Updating $web.AnotherTopic <br/>
Added SomeFile <br/>
HERE

    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );

    $resp = $this->runREST( 'WebHome' );
    $match = <<"HERE";
Attachments updated 0, added 0, removed 0, ignored 0 <br/><br/>
HERE
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );
}


#  Test updating an attachment and verify size recorded in Metadata
#
#  Test that view and change auth are honored
#
#  Test 4 options together,  add, update, remove, ignored
#
#  Test Attach as user & verify metadata
#
#  Test removing all attachments 
#

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
