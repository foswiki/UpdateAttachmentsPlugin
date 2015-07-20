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
use utf8;

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
    $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachFilter} = '^(\\.htaccess|\\.htpasswd|\\.htgroup|_.*)$';

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

    # Compose the query
    my $query = Unit::Request->new(
        {
            'topic'      => "$web.$topic",
            't'          => time(),
        }
    );
    $query->path_info("/UpdateAttachmentsPlugin/update");

    my $session = Foswiki->new( $Foswiki::cfg{AdminUserLogin}, $query );
    my $text = "Ignore this text";

    # invoke the save handler
    my ( $resp, $result, $stdout, $stderr ) = $this->captureWithKey( rest => $this->getUIFn('rest'), $session );

    #print STDERR "$stderr\n";
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
attachments updated : 0
attachments added   : 1
attachments removed : 0
attachments ignored : 0
HERE

    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );

    $resp = $this->runREST( 'WebHome' );
    $match = <<"HERE";
attachments updated : 0
attachments added   : 0
attachments removed : 0
attachments ignored : 0
HERE
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );
}

sub test_Utf8Attachment {
    my $this = shift;

    my $web = $this->{attach_web};

    _writeTopic( $this, $web, 'AśčÁŠŤśěž', <<HERE );
Topic Text
HERE

    _writeFile( $web, 'AśčÁŠŤśěž', 'AśčÁŠŤśěžFile');

    # first run - attach one file.

    my $resp = $this->runREST( 'WebHome' );

    my $match = <<"HERE";
attachments updated : 0
attachments added   : 1
attachments removed : 0
attachments ignored : 0
HERE

    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );

    $resp = $this->runREST( 'WebHome' );
    $match = <<"HERE";
attachments updated : 0
attachments added   : 0
attachments removed : 0
attachments ignored : 0
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
attachments updated : 0
attachments added   : 0
attachments removed : 1
attachments ignored : 0
HERE

    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );

    # Run tes a 2nd time - nothing to remove.
    my $resp2 = $this->runREST( 'WebHome' );

    $match = <<"HERE";
attachments updated : 0
attachments added   : 0
attachments removed : 0
attachments ignored : 0
HERE

    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp2);#, "Unexpected output from initial attach" );

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
attachments updated : 0
attachments added   : 0
attachments removed : 0
attachments ignored : 1
HERE
    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "Unexpected output from initial attach" );

}

#
#   Verify that a internal attachment name is not attached,
#   and is not reported as ignored.  (Don't expose existance of operational files like .htpasswd
#
sub test_internalAttachment {
    my $this = shift;

    my $web = $this->{attach_web};

    _writeTopic( $this, $web, 'AnotherTopic', <<HERE );
Topic Text
HERE

    _writeFile( $web, 'AnotherTopic', '.htaccess');
    _writeFile( $web, 'AnotherTopic', '.htpasswd');

    my $resp = $this->runREST( 'WebHome' );
    my $match = <<"HERE";
attachments updated : 0
attachments added   : 0
attachments removed : 0
attachments ignored : 0
HERE
    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "internal files should not be attached" );

}

#
#   Verify that a other "hidden" attachments are attached,
#
sub test_dotPrefixAttachments {
    my $this = shift;

    my $web = $this->{attach_web};

    _writeTopic( $this, $web, 'AnotherTopic', <<HERE );
Topic Text
HERE

    _writeFile( $web, 'AnotherTopic', '.bashrc');
    _writeFile( $web, 'AnotherTopic', '.keep');

    my $resp = $this->runREST( 'WebHome' );
    my $match = <<"HERE";
attachments updated : 0
attachments added   : 2
attachments removed : 0
attachments ignored : 0
HERE
    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "internal files should not be attached" );

}
#
#   Verify that a hidden attachment name is not attached,
#   and is reported as being ignored.
#
sub test_hiddenAttachment {
    my $this = shift;

    my $web = $this->{attach_web};

    _writeTopic( $this, $web, 'AnotherTopic', <<HERE );
Topic Text
HERE

    _writeFile( $web, 'AnotherTopic', '_hideMe.txt');

    my $resp = $this->runREST( 'WebHome' );
    my $match = <<"HERE";
attachments updated : 0
attachments added   : 0
attachments removed : 0
attachments ignored : 0
HERE
    chomp $match;
    $this->assert_matches( qr#.*$match.*#, $resp, "hidden files should not be attached" );

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
#  Test valid prefixed attachments, .bashrc for example
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
