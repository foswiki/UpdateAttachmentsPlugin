#---+ Extensions
#---++ Update Attachments Plugin
# **STRING**
# To attribute attachments to a known user, set this to their WikiName. This user should exist,
# and be mappable to a login.  If not set, the default UnknownUser will be used.
# <br/><br/>
# Note that the rest handler always runs under the current authenticated user.  This attribute is
# only used to populate the user field in the attachment table, and does not affect access rights.
$Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser} = '';
# **BOOLEAN**
# Remove references to attachments that no longer exist in pub.
$Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{RemoveMissing} = $TRUE;
# **BOOLEAN**
# Enable debugging messages - printed to STDERR (Apache error_log file)
$Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{Debug} = $FALSE;
