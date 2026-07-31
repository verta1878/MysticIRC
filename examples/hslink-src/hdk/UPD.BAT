if exist print.out copy print.out hdk.doc
if exist print.out del print.out
pkzip -f hdk *.* include\*.*
pkzip -f hdksc *.* include\*.*
