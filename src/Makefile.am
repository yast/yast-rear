# Makefile.am for rear/src

yncludedir = @yncludedir@/rear

client_DATA =			\
	rear.ycp		\
	rear_auto.ycp	\
	rear_proposal.ycp

ynclude_DATA =			\
	helps.ycp		\
	wizards.ycp		\
	dialogs.ycp		\
	complex.ycp

desktop_DATA =			\
	rear.desktop

module_DATA =			\
	Rear.ycp		\
	Rear2.pm		\
	Rear3.py

# create a symlink for local build, #145327
rear:
	ln -sf . $@
ycpchook = rear

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
