package Foswiki::Plugins::UpdateAttachmentsPlugin::Core;
use strict;
use warnings;

use Foswiki::Plugins ();
use Foswiki::Func ();
use Foswiki::Sandbox ();
use Error qw(:try);

use constant DRY => 0;
use constant TRACE => 0;

BEGIN {

    # Import the locale for sorting
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

 # Shamelessly copied from  Foswiki Store

    if ($Foswiki::UNICODE) {
        require Encode;

        # Interface to file operations.

        *_decode = \&Foswiki::Store::decode;

        # readdir returns bytes
        *_readdir = sub {
            map { _decode($_) } readdir( $_[0] );
        };

        *_encode = \&Foswiki::Store::encode;

        # The remaining file level functions work on wide chars,
        # silently converting to utf-8. But we want to explicitly
        # control the encoding in the {Store}{Encoding}!=undef case,
        # so we have no choice but to override.
        *_unlink = sub { unlink( _encode( $_[0] ) ); };
        *_e      = sub { -e _encode( $_[0] ); };
        *_f      = sub { -f _encode( $_[0] ); };
        *_d      = sub { -d _encode( $_[0] ); };
        *_r      = sub { -r _encode( $_[0] ); };
        *_stat   = sub { stat( _encode( $_[0] ) ); };
        *_utime  = sub { utime( $_[0], $_[1], _encode( $_[2] ) ); };
    }
    else {
        *_decode = sub { };
        *_encode = sub { };
        *_unlink = \&unlink;
        *_readdir = \&readdir;
        *_e       = sub { -e $_[0] };
        *_f       = sub { -f $_[0] };
        *_d       = sub { -d $_[0] };
        *_r       = sub { -r $_[0] };
        *_stat    = \&stat;
        *_utime   = \&utime;
    }
}

sub new {
  my $class = shift;

  my $this = bless({
      debug => $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{Debug} || TRACE,
      attachFilter => $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachFilter},
      checkUpdateAttachPermission => $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{CheckUPDATEATACHPermission} || 0,
      attachAsUser => $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser},
      removeMissing => $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{RemoveMissing},
      @_
    },
    $class
  );

  $this->{attachFilter} = '^(\\.htaccess|\\.htpasswd|\\.htgroup|_.*|igp_.*|genpdf_.*|gnuplot_.*)$'
    unless defined $this->{attachFilter};

  $this->{removeMissing} = 1
    unless defined $this->{removeMissing};

  $this->{attachAsUser} = Foswiki::Func::getCanonicalUserID($this->{attachAsUser})
    if $this->{attachAsUser};

  return $this;
}

sub init {
  my $this = shift;

  $this->{topicsTested} = 0;
  $this->{topicsUpdated} = 0;
  $this->{attachmentsIgnored} = 0;
  $this->{attachmentsRemoved} = 0;
  $this->{attachmentsRetained} = 0;
  $this->{attachmentsAdded} = 0;
  $this->{attachmentsUpdated} = 0;
  $this->{changed} = 0;
  $this->{detailedReport} = undef;

  return $this;
}

sub restUpdate {
  my ($this, $session, $plugin, $verb, $response) = @_;

  $this->init;

  my $request = Foswiki::Func::getRequestObject();

  my $mode = $request->param("mode") || 'web';
  my $topicNames = $request->param("list");

  $mode = 'topics' if $topicNames;

  my $web = $session->{webName};

  my @topicNames = ();
  if ($mode eq 'topic') {
    # update the current topic
    push @topicNames, $session->{topicName};
  } elsif ($mode eq 'topics' && $topicNames) {
    # update a list of topics
    push @topicNames, split(/\s*,\s*/, $topicNames);
  } elsif ($mode eq 'web') {
    # update all of the web
    push @topicNames, Foswiki::Func::getTopicList($web);
  } elsif ($mode eq 'preferences') {
    $topicNames = Foswiki::Func::getPreferencesValue("UPDATEATTACHMENTS") || '';
    push @topicNames, split(/\s*,\s*/, $topicNames);
  } else {
    throw Error::Simple("unknown mode '$mode'");
  }

  #TODO: $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{BatchLimit}

  foreach my $topic (@topicNames) {
    $this->updateAttachments($web, $topic);
  }

  $response->header(-type => "text/plain");

  push @{$this->{detailedReport}}, "topics tested : " . $this->{topicsTested};
  push @{$this->{detailedReport}}, "topics updated: " . $this->{topicsUpdated};
  push @{$this->{detailedReport}}, "attachments updated : " . $this->{attachmentsUpdated};
  push @{$this->{detailedReport}}, "attachments added   : " . $this->{attachmentsAdded};
  push @{$this->{detailedReport}}, "attachments removed : " . $this->{attachmentsRemoved} if $this->{removeMissing};
  push @{$this->{detailedReport}}, "attachments retained: " . $this->{attachmentsRetained} unless $this->{removeMissing};
  push @{$this->{detailedReport}}, "attachments ignored : " . $this->{attachmentsIgnored};

  return join("\n", @{$this->{detailedReport}})."\n\n";
}

sub writeDebug {
  my ($this, $msg) = @_;

  return unless $this->{debug};
  print STDERR $msg . "\n";
}

sub updateAttachments {
  my ($this, $web, $topic) = @_;

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);

  my $wikiName = Foswiki::Func::getWikiName();

  return unless Foswiki::Func::topicExists($web, $topic);

  $this->writeDebug("===  Processing $web.$topic");

  my ($obj, $text) = Foswiki::Func::readTopic($web, $topic);

  if (!Foswiki::Func::checkAccessPermission("VIEW", $wikiName, undef, $topic, $web, $obj)) {
    push @{$this->{detailedReport}}, "bypassed $web.$topic - no permission to VIEW";
    return;
  }

  if (!Foswiki::Func::checkAccessPermission("CHANGE", $wikiName, undef, $topic, $web, $obj)) {
    push @{$this->{detailedReport}}, "bypassed $web.$topic - no permission to CHANGE";
    return;
  }

  if ($this->{checkUpdateAttachPermission}
    && !Foswiki::Func::checkAccessPermission("UPDATEATTACH", $wikiName, undef, $topic, $web, $obj))
  {
    push @{$this->{detailedReport}}, "bypassed $web.$topic - no permission to UPDATEATTACH";
    return;
  }

  push @{$this->{detailedReport}}, "=== Processing $web.$topic";
  my @newAttachments = $this->getNewAttachmentsList($obj);

  if ($this->{changed}) {
    $obj->putAll('FILEATTACHMENT', @newAttachments);
    Foswiki::Func::saveTopic($web, $topic, $obj, $text, {
      comment => 'updated attachments',
      dontlog => 1,
      minor => 1,
    }) unless DRY;
    $this->{topicsUpdated}++;
    push @{$this->{detailedReport}}, "saving new attachments list";
  }
  $this->{topicsTested}++;
}

sub getNewAttachmentsList {
  my ($this, $obj) = @_;

  my %filesInPub = $this->getFilesInPub($obj);
  my %filesInMeta = map { $_->{name} => $_ } $obj->find('FILEATTACHMENT');
  $this->{changed} = 0;

  foreach my $file (keys %filesInPub) {
    my $validated = Foswiki::Sandbox::validateAttachmentName($file);

    # check for badly named attachments
    unless (defined $validated && $validated eq $file) {
      $this->{attachmentsIgnored}++;
      push @{$this->{detailedReport}}, "ignoring '$file' - not a valid attachment name";
      next;
    }

    # check pub file in current meta
    if ($filesInMeta{$file}) {

      if ( $filesInMeta{$file}{size} ne $filesInPub{$file}{size}
        || $filesInMeta{$file}{date} ne $filesInPub{$file}{date})
      {
        # found changed pub file
        $filesInPub{$file}{autoattached} = "1";
        $this->{attachmentsUpdated}++;
        push @{$this->{detailedReport}}, "updated $file";
        $this->{changed} = 1;
      }

      # bring forward any missing yet wanted attribute
      foreach my $field (qw(comment attr user version autoattached)) {
        if ($filesInMeta{$file}{$field}) {
          $filesInPub{$file}{$field} =
            $filesInMeta{$file}{$field};
        }
      }
    } else {

      # new pub file found
      $filesInPub{$file}{autoattached} = "1";
      $filesInPub{$file}{user} = $this->{attachAsUser} if $this->{attachAsUser};
      $this->{attachmentsAdded}++;
      push @{$this->{detailedReport}}, "added $file";
      $this->{changed} = 1;
    }
  }

  # A comparison of the keys of the $filesInMeta and %filesInPub
  # would show files that were in Meta but have disappeared from Pub.

  foreach my $file (keys %filesInMeta) {

    next unless !$filesInPub{$file};

    my $validated = Foswiki::Sandbox::validateAttachmentName($file);
    next unless defined $validated && $validated eq $file;

    if ($this->{removeMissing}) {
      $this->{attachmentsRemoved}++;
      push @{$this->{detailedReport}}, "removed $file";
      $this->{changed} = 1;
    } else {
      $filesInPub{$file} = $filesInMeta{$file};
      $this->{attachmentsRetained}++;
      push @{$this->{detailedReport}}, "retaining missing attachment $file";
      $this->{changed} = 1;
    }
  }

  return () unless $this->{changed};

  return values(%filesInPub);
}

sub getFilesInPub {
  my ($this, $obj) = @_;

  my $dir = "$Foswiki::cfg{PubDir}/" . $obj->web() . '/' . $obj->topic();
  my $dh;

  opendir($dh, $dir) || return ();
  my @files =
    grep { !/$this->{attachFilter}/ && !/,v$/ && _f "$dir/$_" } _readdir($dh);
  closedir($dh);

  my %fileStats = ();
  foreach my $file (@files) {

    my @stat = _stat($dir . "/" . $file);
    next unless @stat;

    $fileStats{$file} = {
      name => $file,
      version => '',
      path => $file,
      size => $stat[7],
      date => $stat[9],
      comment => '',
      attr => '',
    };
  }

  return %fileStats;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2007-2012 SvenDowideit@fosiki.com

Copyright (C) 2010-2014 Foswiki Contributors. Foswiki Contributors
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
