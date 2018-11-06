# tufts-dca-archivesspace-plugins
**Directions for Installing Modified DOM Controller**

**Purpose:** Apply modified Digital Object Manager plugin for
ArchivesSpace so it can update or create digital objects, depending on
the number of fields in the input CSV

**Modifications to the Plugin:**

Tufts University modified the backend controller for this plugin,
digital\_object\_manager\_controller.rb, as well as changing some
language in the frontend view index.html.rb

The features we added were the ability to either create or update a
digital object, depending on how many input fields in the uploaded CSV
had data in them.

The directions on how to upload have more information on this, but if
you use this modification, the input CSV **must have 9 fields per
line**. **If you intend to update existing digital objects** on the
archival object represented by the PID in field 2, **you should leave
one or more of the input fields in the CSV blank**. Still include the
fields, but don't put anything in them. For instance if you were doing
an update, your input line might look like this:

,MS001.001,updated.handle.url.123.org,A New Location,,,,,

**For creating a digital object, you have to make sure every one of the
9 fields has data in it.**

You can mix lines for updates and lines to create digital objects. For
instance, the following updates digital objects for line 1, and creates
an object for line 2. (Line 2 appears as two lines in this document.)

,MS001.001,updated.handle.url.123.org,A New Location,,,,,

Archival Object Title,MS102.001,updated.handle.url.123.org, A New
Location,True,Open for research,True,1234FHFDHASH,Bagger

The log file that the plugin generates has more information on whether
the digital object was updated or created, how many fields were updated,
whether each operation was successful, and error messages if there were
issues.

**Steps:**

-   Replace the digital\_object\_manager plugin in your plugins
    directory with the supplied version for these modifications. Provide
    this plugin to whoever manages your application on the backend if
    you don't handle this yourself.

-   Note that you **need to change the controller code to input the
    digital object prefix used by your institution.** The controller
    code has comment blocks explaining where this needs to changed

-   Restart ASpace.

**Troubleshooting:**

-   If you're getting errors either in the log file, or you come to a
    red error screen in ArchivesSpace, there's likely an issue with your
    input data.

-   Common causes might be the wrong number of fields in the plugin or
    an unexpected value in fixed value fields such as something other
    than True/False for a Boolean field, or something other than "Open
    for research" or blank for restrictions.

-   Or you could be referencing a non-existent archival object PID.
