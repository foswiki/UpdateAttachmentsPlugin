#---++ Extensions
#---++ Update Attachments Plugin
# **STRING**
# To attribute attachments to a known user, set this to their WikiName. This user should exist,
# and be mappable to a login. 
$Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser} = '';
# **BOOLEAN**
# remove references to attachments that no longer exist in pub
$Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{RemoveMissing} = $FALSE;
# **BOOLEAN**
# use the _internal_ _noHandlersSave - This option causes the topic update code to write directly into the
# Store, bypassing the API's and other Handlers.  This is *Strongly* not recommended.  This may break in 
# future and is not recomended unless you know the code.
$Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{UseDangerousNoHandlersSave} = $FALSE;
