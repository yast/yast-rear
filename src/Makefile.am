# Sources for rear

module_DATA = \
  modules/RearSystemCheck.rb \
  modules/Rear.rb

client_DATA = \
  clients/rear.rb

yncludedir = @yncludedir@/rear
ynclude_DATA = \
  include/rear/ui.rb

ylibdir = "${yast2dir}/lib/rear"
ylib_DATA = \
  lib/rear/*.rb

scrconf_DATA = \
  scrconf/rear_conf.scr

desktop_DATA = \
  desktop/rear.desktop

scalabledir = @icondir@/hicolor/scalable/apps
scalable_DATA = \
  icons/hicolor/scalable/apps/yast-backup.svg

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(ylib_DATA) $(scrconf_DATA) $(desktop_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
