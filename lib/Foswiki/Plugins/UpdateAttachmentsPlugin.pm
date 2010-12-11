# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# copyright 2007-2009 SvenDowideit@fosiki.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::UpdateAttachmentsPlugin;
use strict;

our $VERSION = '$Rev$';
our $RELEASE = 'Foswiki-1.0';
our $SHORTDESCRIPTION = 'A batched alternative to AutoAttachments (adds and removes attachements)';
our $NO_PREFS_IN_TOPIC = 1;

my $debug = 0;

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 2.1 ) {
        Foswiki::Func::writeWarning( "Version mismatch between UpdateAttachmentsPlugin  and Plugins.pm" );
        return 0;
    }
    
    $debug = $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{Debug} || 0;
    Foswiki::Func::registerRESTHandler('update', \&restUpdate);
    return 1;
}


sub restUpdate {
    my $session = shift;
    my $store = $session->{store};
    my $web = $session->{webName};
  
    print STDERR "update the attachments of $web\n" if $debug;
    
    #force autoattach off, as we need to know the real META
    my $cfgAutoAttach = $Foswiki::cfg{AutoAttachPubFiles};
    $Foswiki::cfg{AutoAttachPubFiles} = 0;
    
    #TODO: consider the lighter weight aproach of scanning timestamps in the pub dir
    #      checking&updating only those topics that have newer timestamp pub files
    #      (it would only helps adding attachments, not removing them)
    
    my $topicsTested = 0;
    my $topicsUpdated = 0;
    my $attachmentsIgnored = 0;
    my $attachmentsRemoved = 0;
    my $attachmentsAdded = 0;
    my $attachmentsUpdated = 0;

    #TODO: test user's access to web (rest already tests for web CHANGE access)
    my @topicNames = Foswiki::Func::getTopicList( $web );
    foreach my $topic (@topicNames) {
        # test user's permission on this topic (do this first, eventually this check may not read the topic.. for now it will populate the cache)
        next if (!Foswiki::Func::checkAccessPermission( 'CHANGE', Foswiki::Func::getWikiName(), undef, $topic, $web ));

        my $changed = 0;

        my $topicObject = Foswiki::Meta->load($session, $web, $topic);
        my @knownAttachments = $topicObject->find('FILEATTACHMENT');
        my ($attachmentsFoundInPub, $attachmentsRemovedFromMeta, $attachmentsAddedToMeta, $attachmentsUpdatedInMeta) =
          synchroniseAttachmentsList($topicObject, \@knownAttachments );
        my @validAttachmentsFound;
        foreach my $foundAttachment (@$attachmentsFoundInPub) {

            # test if the attachment filename is valid without having to
            # be sanitized. If not, ignore it.
            my $validated = Foswiki::Sandbox::validateAttachmentName(
                $foundAttachment->{name} );
            unless ( defined $validated
                && $validated eq $foundAttachment->{name} )
            {

                print STDERR 'AutoAttachPubFiles ignoring '
                  . $foundAttachment->{name} . ' in '
                  . $topicObject->getPath()
                  . ' - not a valid Foswiki Attachment filename';
            }
            else {
                push @validAttachmentsFound, $foundAttachment;
            }
        }

        $topicObject->putAll( 'FILEATTACHMENT', @validAttachmentsFound )
          if @validAttachmentsFound;


        #TODO: actually test that they are the same! (update size, date etc)
        print STDERR "$web.$topic has ".scalar(@knownAttachments)." in meta, ".scalar(@$attachmentsFoundInPub)." in pub dir\n" if $debug;

        $changed = scalar(@$attachmentsRemovedFromMeta) + scalar(@$attachmentsAddedToMeta) + scalar(@$attachmentsUpdatedInMeta);

        if ($changed) {
            $topicObject->save(  comment => 'UpdateAttachments' );
            print STDERR "updating the attachments of $web.$topic\n" if $debug;
            $topicsUpdated++;
            $attachmentsRemoved += scalar(@$attachmentsRemovedFromMeta);
            $attachmentsAdded += scalar(@$attachmentsAddedToMeta);
            $attachmentsUpdated += scalar(@$attachmentsUpdatedInMeta);
        }
        $topicsTested++;
        #TODO: $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{BatchLimit}

    }

    print STDERR "UpdateAttachments checked $topicsTested, updated $topicsUpdated,   removed $attachmentsRemoved attachments, $attachmentsIgnored ignored" if $debug;

    # Restore auto-attach setting.   (This *really* ought to be disabled if using this plugin
    $Foswiki::cfg{AutoAttachPubFiles} = $cfgAutoAttach ;

    return "UpdateAttachments Topics checked $topicsTested, updated $topicsUpdated, <br/> Attachments updated $attachmentsUpdated, added $attachmentsAdded, removed $attachmentsRemoved attachments, $attachmentsIgnored ignored";
}

=begin TML

---++ ObjectMethod synchroniseAttachmentsList(\@old) -> @new

*Copied directly from Foswiki::Store::VC::Handler.pm*

Synchronise the attachment list from meta-data with what's actually
stored in the DB. Returns an ARRAY of FILEATTACHMENTs. These can be
put in the new tom.

=cut

# IDEA On Windows machines where the underlying filesystem can store arbitary
# meta data against files, this might replace/fulfil the COMMENT purpose

sub synchroniseAttachmentsList {
    my ( $topicObject, $attachmentsKnownInMeta ) = @_;

    my %filesListedInPub  = _getAttachmentStats($topicObject);
    my %filesListedInMeta = ();
    my %filesToAddToMeta = ();
    my @filesRemovedFromMeta = ();
    my @filesAddedToMeta = ();
    my @filesUpdatedInMeta = ();

    # You need the following lines if you want metadata to supplement
    # the filesystem
    if ( defined $attachmentsKnownInMeta ) {
        %filesListedInMeta =
          map { $_->{name} => $_ } @$attachmentsKnownInMeta;
    }

    foreach my $file ( keys %filesListedInPub ) {
        if ( $filesListedInMeta{$file} ) {
            if ( $filesListedInMeta{$file}{size} ne $filesListedInPub{$file}{size} ||
                 $filesListedInMeta{$file}{date} ne $filesListedInPub{$file}{date} ) {
                $filesListedInPub{$file}{autoattached} = "1";
                push @filesUpdatedInMeta, $file;
                print STDERR "Updating $file \n";
            }
            # Bring forward any missing yet wanted attribute
            foreach my $field qw(comment attr user version autoattached) {
                if ( $filesListedInMeta{$file}{$field} ) {
                    $filesListedInPub{$file}{$field} =
                      $filesListedInMeta{$file}{$field};
                }
            }
        }
        else {
            #default attachment owner to {AttachAsUser}
            push @filesAddedToMeta, $file;
            print STDERR "Adding $file \n";
            $filesListedInPub{$file}{autoattached} = "1";
            if ((defined($Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser})) &&
                ($Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser} ne '')) {
                $filesListedInPub{$file}{user} = $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser};
                #TODO: needs testing for the generalised usermapping case - shoudl store cUID
            }
        }
    }

    # A comparison of the keys of the $filesListedInMeta and %filesListedInPub
    # would show files that were in Meta but have disappeared from Pub.

    foreach my $file ( keys %filesListedInMeta ) {
        if (! $filesListedInPub{$file} ) {
            print STDERR "Removing $file \n";
            push @filesRemovedFromMeta, $file;
        }
    }

    # Do not change this from array to hash, you would lose the
    # proper attachment sequence
    my @deindexedBecauseMetaDoesnotIndexAttachments = values(%filesListedInPub);

    return \@deindexedBecauseMetaDoesnotIndexAttachments, \@filesRemovedFromMeta, \@filesAddedToMeta, \@filesUpdatedInMeta;
}

=begin TML

---++ ObjectMethod getAttachmentList() -> @list

Get list of attachment names actually stored for topic.

=cut

sub getAttachmentList {
    my $topicObject = shift;
    my $dir  = "$Foswiki::cfg{PubDir}/" . $topicObject->web() . "/" . $topicObject->topic();
    my $dh;
    opendir( $dh, $dir ) || return ();
    my @files = grep { !/^[.*_]/ && !/,v$/ } readdir($dh);
    closedir($dh);
    return @files;
}

# returns {} of filename => { key => value, key2 => value }
# for any given web, topic
sub _getAttachmentStats {
    my $topicObject           = shift;
    my %attachmentList = ();
    my $dir            = "$Foswiki::cfg{PubDir}/" . $topicObject->web() . '/' . $topicObject->topic();
    foreach my $attachment ( getAttachmentList($topicObject) ) {
        my @stat = stat( $dir . "/" . $attachment );
        $attachmentList{$attachment} =
          _constructAttributesForAutoAttached( $attachment, \@stat );
    }
    return %attachmentList;
}

# as long as stat is defined, return an emulated set of attributes for that
# attachment.
sub _constructAttributesForAutoAttached {
    my ( $file, $stat ) = @_;

    my %pairs = (
        name    => $file,
        version => '',
        path    => $file,
        size    => $stat->[7],
        date    => $stat->[9],

#        user    => 'UnknownUser',  #safer _not_ to default - Foswiki will fill it in when it needs to
        comment      => '',
        attr         => '',
    );

    if ( $#$stat > 0 ) {
        return \%pairs;
    }
    else {
        return;
    }
}

1;
