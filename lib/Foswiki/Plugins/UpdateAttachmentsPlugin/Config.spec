#---+ Extensions
#---++ Update Attachments Plugin
# **STRING**
# To attribute attachments to a known user, set this to their WikiName. This user should exist,
# and be mappable to a login.  If not set, the default UnknownUser will be used.
$Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser} = '';
# **BOOLEAN**
# Remove references to attachments that no longer exist in pub.
$Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{RemoveMissing} = $TRUE;
# **BOOLEAN**
# Enable debugging messages - printed to STDERR (Apache error_log file)
$Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{Debug} = $FALSE;
