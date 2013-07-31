# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:	clients/rear.ycp
# Package:	Configuration of rear
# Summary:	Main file
# Authors:	Thomas Goettlicher <tgoettlicher@suse.de>
#
# $Id$
#
# Main file for rear configuration. Uses all other files.
module Yast
  class RearClient < Client
    def main
      Yast.import "UI"

      #**
      # <h3>Configuration of rear</h3>

      textdomain "rear"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Rear module started")

      Yast.import "CommandLine"
      Yast.import "Rear"

      Yast.include self, "rear/ui.rb"



      @cmdline_description = {
        "id"         => "rear",
        # Command line help text for the Xrear module
        "help"       => _(
          "Configuration of Rear"
        ),
        "guihandler" => fun_ref(method(:RearSequence), "symbol ()"),
        "initialize" => fun_ref(Rear.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Rear.method(:Write), "boolean ()"),
        "actions"    => {
          "configure" => {
            "handler" => fun_ref(
              method(:RearChangeConfiguration),
              "boolean (map)"
            ),
            # command line help text for 'configure' action
            "help"    => _(
              "Change the Rear configuration"
            )
          }
        },
        "options"    => {
          "output"    => { "help" => _("Output"), "type" => "string" },
          "netfs_url" => { "help" => _("Netfs URL"), "type" => "string" }
        },
        "mappings"   => { "configure" => ["output", "netfs_url"] }
      }


      # main ui function
      @ret = CommandLine.Run(@cmdline_description)

      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Rear module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end

    # --------------------------------------------------------------------------
    # --------------------------------- cmd-line handlers

    # Command line handler for changing basic configuration
    # @param [Hash] options  a list of parameters passed as args
    # (currently only "port" key is expected)
    # @return [Boolean] true on success
    def RearChangeConfiguration(options)
      options = deep_copy(options)
      output = Ops.get_string(options, "output", "")
      netfs_url = Ops.get_string(options, "netfs_url", "")

      if output != ""
        Rear.output = output
        Rear.modified = true
        return true
      end

      if netfs_url != ""
        Rear.netfs_url = netfs_url
        Rear.modified = true
        return true
      end

      false
    end
  end
end

Yast::RearClient.new.main
