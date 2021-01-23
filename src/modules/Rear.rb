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

# File:	modules/Rear.ycp
# Package:	Configuration of rear
# Summary:	Rear settings, input and output functions
# Authors:	Thomas Goettlicher <tgoettlicher@suse.de>
#
# $Id$
#
# Representation of the Rear configuration.
# Input and output routines.
require "yast"
require "y2storage"
require "shellwords"

module Yast
  class RearClass < Module
    def main
      textdomain "rear"

      Yast.import "FileUtils"
      # Data was modified?
      @modified = false

      @backup = ""
      @output = ""
      @netfs_url = ""
      @backup_options = ""
      @netfs_keep_old_backup = true
      @use_dhclient = false
      @modules_load = []
      @backup_prog_include = []
      @copy_as_is = []
      @usbpartitions = {}
    end

    # Returns a Map of Partitons on USB Volumes
    #
    def GetUsbPartitions
      usbdevs = []
      usbparts = {}

      storage = Y2Storage::StorageManager.instance
      # (re)probe. Reprobing is safe because yast2-rear is always executed
      # standalone, never as part of the installer.
      storage.probe

      storage.probed.disks.select(&:usb?).each do |disk|
        disk.partitions.reject { |i| i.type.is?(:extended) }.each do |part|
          usbparts["usb://#{part.name}"] = "#{part.name} (#{part.size.to_human_string})"
        end
      end
      @usbpartitions = deep_copy(usbparts)
      deep_copy(usbparts)
    end

    # The module distinguishes between two types of lists that are used in the ReaR configuration.
    # They are called by this code as basic and quoted lists.
    # * A basic list consists of as-is names. Elements of this list are not transformed in any way
    #   when being written to or read from the configuration file, with the exception of escaping
    #   spaces.
    # * A quoted list consists of names that should be protected from shell processing. Elements of
    #   such a list are quoted when writing them in the configuration file and unquoted/unescaped
    #   when reading them. This is used to store scripts that are invoked by ReaR using
    #   'eval "${CONFIG_VAR[@]}"' and for wildcard names that should not be expanded by the shell
    #   directly.

    # Convert List from Config File to YCP List
    def RearListToYCPList(rearlist)
      return [] if rearlist == nil

      # remove parentheses
      rearlist = Builtins.regexpsub(Convert.to_string(rearlist), "^ *\\((.*)\\) *$", "\\1")

      # split string separated by spaces into a string list, respect backslash escaped blanks
      ycplisttmp = rearlist.split(" ")
      ycplist = []
      buffer = ""
      ycplisttmp.each do |elem|
        if elem[-1] == "\\"
          buffer += elem[0...-1] + " "
        else
          buffer += elem
          ycplist.push(buffer)
          buffer = ""
        end
      end

      # remove empty elements
      ycplist = ycplist.select { |elem| elem != "" }

      deep_copy(ycplist)
    end

    # Convert YCP List to Format for Config File
    def YCPListToRearList(ycplist)
      # escape blanks in directories with a backslash
      escaped = ycplist.map { |elem| elem.gsub(" ", "\\ ") }

      "(" + escaped.join(" ") + ")"
    end

    # Convert Quoted List from Config File to YCP List
    def RearQuotedListToYCPList(rearlist)
      return [] if rearlist == nil

      # remove parentheses
      rearlist = Builtins.regexpsub(Convert.to_string(rearlist), "^ *\\((.*)\\) *$", "\\1")

      # split string separated by spaces into a string list, respect shell quoting
      ycplist = Shellwords.split(rearlist);

      # remove empty elements
      ycplist = ycplist.select { |elem| elem != "" }

      deep_copy(ycplist)
    end

    # Convert YCP List to Quoted Format for Config File
    def YCPListToRearQuotedList(ycplist)
      # escape all commands by putting them in single quotes, instead of using Shellwords.escape
      # which would escape each individual character thus making the result harder to read
      escaped = ycplist.map { |elem| "'" + String.Quote(elem) + "'" }

      "(" + escaped.join(" ") + ")"
    end

    # Read rear settings from /etc/rear/local.conf
    # returns true when file exists
    def ReadSysconfig
      if FileUtils.Exists("/etc/rear/local.conf")
        @backup = Convert.to_string(SCR.Read(path(".etc.rear_conf.v.BACKUP")))
        @backup ||= ""

        @output = Convert.to_string(SCR.Read(path(".etc.rear_conf.v.OUTPUT")))
        @output ||= ""

        @netfs_url = SCR.Read(path(".etc.rear_conf.v.BACKUP_URL"))
        @netfs_url ||= ""

        @backup_options = SCR.Read(path(".etc.rear_conf.v.BACKUP_OPTIONS"))
        @backup_options ||= ""

        # rear interprets all non-empty values as yes
        netfs_keep_old_backup_tmp = Convert.to_string(
          SCR.Read(path(".etc.rear_conf.v.NETFS_KEEP_OLD_BACKUP_COPY"))
        )
        if netfs_keep_old_backup_tmp != "" && netfs_keep_old_backup_tmp != nil
          @netfs_keep_old_backup = true
        else
          @netfs_keep_old_backup = false
        end

        use_dhclient_tmp = SCR.Read(path(".etc.rear_conf.v.USE_DHCLIENT"))
        @use_dhclient = use_dhclient_tmp != "" && use_dhclient_tmp != nil

        modules_load_tmp =
          SCR.Read(path(".etc.rear_conf.v.MODULES_LOAD"))
        @modules_load = RearListToYCPList(modules_load_tmp)

        backup_prog_include_tmp =
          SCR.Read(path(".etc.rear_conf.v.BACKUP_PROG_INCLUDE"))
        @backup_prog_include = RearQuotedListToYCPList(backup_prog_include_tmp)

        post_recovery_script_tmp = 
          SCR.Read(path(".etc.rear_conf.v.POST_RECOVERY_SCRIPT"))
        @post_recovery_script = RearQuotedListToYCPList(post_recovery_script_tmp)

        # These two configuration parameters extend a rear system variable.
        # It is bash, so this is done by including the old value of that variable
        # in the new value.
        # We remove it here, because we don't want to give the user the option to
        # remove it. Before saving it gets added back again.
        required_progs_tmp = SCR.Read(path(".etc.rear_conf.v.REQUIRED_PROGS"))
        @required_progs = RearListToYCPList(required_progs_tmp)
        @required_progs.delete("${REQUIRED_PROGS[@]}")

        copy_as_is_tmp = SCR.Read(path(".etc.rear_conf.v.COPY_AS_IS"))
        @copy_as_is = RearListToYCPList(copy_as_is_tmp)
        @copy_as_is.delete("${COPY_AS_IS[@]}")

        return true
      end
      false
    end

    # Read all rear settings
    def Read
      GetUsbPartitions()
      ReadSysconfig()
      true
    end

    # Write all rear settings
    def Write
      return true if !@modified

      SCR.Write(path(".etc.rear_conf.v.BACKUP"), "NETFS")

      SCR.Write(path(".etc.rear_conf.v.OUTPUT"), @output) if @output != ""

      if @netfs_url != ""
        SCR.Write(path(".etc.rear_conf.v.BACKUP_URL"), @netfs_url)
      end

      SCR.Write(path(".etc.rear_conf.v.BACKUP_OPTIONS"), @backup_options)
      SCR.Write(path(".etc.rear_conf.v.NETFS_KEEP_OLD_BACKUP_COPY"), @netfs_keep_old_backup ? "yes" : "")
      SCR.Write(path(".etc.rear_conf.v.USE_DHCLIENT"), @use_dhclient ? "yes" : "")

      modules_load_tmp = @modules_load != [] ? YCPListToRearList(@modules_load) : "( )"
      SCR.Write(path(".etc.rear_conf.v.MODULES_LOAD"), modules_load_tmp)

      unless @backup_prog_include.empty?
        SCR.Write(
          path(".etc.rear_conf.v.BACKUP_PROG_INCLUDE"),
          YCPListToRearQuotedList(@backup_prog_include)
        )
      end

      unless @post_recovery_script.empty?
        SCR.Write(
          path(".etc.rear_conf.v.POST_RECOVERY_SCRIPT"),
          YCPListToRearQuotedList(@post_recovery_script)
        )
      end

      unless @required_progs.empty?
        @required_progs |= %w(${REQUIRED_PROGS[@]})
        SCR.Write(
          path(".etc.rear_conf.v.REQUIRED_PROGS"),
          YCPListToRearList(@required_progs)
        )
      end

      unless @copy_as_is.empty?
        @copy_as_is |= %w(${COPY_AS_IS[@]})
        SCR.Write(
          path(".etc.rear_conf.v.COPY_AS_IS"),
          YCPListToRearList(@copy_as_is)
        )
      end
      SCR.Write(path(".etc.rear_conf"), nil)
    end

    publish :variable => :modified, :type => "boolean"
    publish :variable => :backup, :type => "string"
    publish :variable => :output, :type => "string"
    publish :variable => :netfs_url, :type => "string"
    publish :variable => :backup_options, :type => "string"
    publish :variable => :netfs_keep_old_backup, :type => "boolean"
    publish :variable => :use_dhclient, :type => "boolean"
    publish :variable => :modules_load, :type => "list <string>"
    publish :variable => :backup_prog_include, :type => "list <string>"
    publish :variable => :post_recovery_script, :type => "list <string>"
    publish :variable => :required_progs, :type => "list <string>"
    publish :variable => :copy_as_is, :type => "list <string>"
    publish :variable => :usbpartitions, :type => "map <string, string>"
    publish :function => :GetUsbPartitions, :type => "map <string, string> ()"
    publish :function => :ReadSysconfig, :type => "boolean ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
  end

  Rear = RearClass.new
  Rear.main
end
