#
# spec file for package yast2-rear
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-rear
Version:        3.2.1
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:          System/YaST
License:        GPL-2.0
BuildRequires:	docbook-xsl-stylesheets doxygen libxslt perl-XML-Writer sgml-skel update-desktop-files yast2 yast2-testsuite yast2-storage
BuildRequires:  yast2-devtools >= 3.1.10
Requires:	yast2
Requires:       rear >= 1.10.0
Requires:       yast2-storage

BuildArchitectures:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - Rear - Relax and Recover

%description
The YaST2 component for configuring Rear - Relax and Recover Backup


%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/rear
%{yast_yncludedir}/rear/*
%{yast_clientdir}/rear.rb
%{yast_moduledir}/RearSystemCheck.*
%{yast_moduledir}/Rear.*
%dir %{yast_libdir}/rear
%{yast_libdir}/rear/*.rb
%{yast_desktopdir}/rear.desktop
%{yast_scrconfdir}/*.scr
%doc %{yast_docdir}
