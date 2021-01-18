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

# File:	modules/RearSystemCheck.ycp
# Package:	system checks for rear support
# Summary:	checks if the system is supported by rear
# Authors:	Thomas Goettlicher <tgoettlicher@suse.de>
#
# $Id$
#
# Checks if the system is supported by rear
require "yast"
require "y2storage"

module Yast
  class RearSystemCheckClass < Module
    @btrfs = false

    def main
      textdomain "rear"

      Yast.import "FileUtils"
    end

    # check bootloader
    # returns error message if system is not supported
    def SystemCheckBootloader
      unsupported = []

      if FileUtils.Exists("/etc/sysconfig/bootloader")
        loader_type = Convert.to_string(
          SCR.Read(path(".sysconfig.bootloader.LOADER_TYPE"))
        )
        if loader_type == nil
          Builtins.y2error(
            "Not supported by rear: Cannot figure out which bootloader is used."
          )
          unsupported = Builtins.add(
            unsupported,
            _("Cannot figure out which bootloader is used.")
          )
        end
        if loader_type != "grub" && loader_type != "grub2" && loader_type != "grub2-efi"
          Builtins.y2error(
            Builtins.sformat(
              "Not supported by rear: bootloader %1 is used.",
              loader_type
            )
          )
          unsupported = Builtins.add(
            unsupported,
            Builtins.sformat(_("Bootloader %1 is used."), loader_type)
          )
        end
      else
        Builtins.y2error(
          "Not supported by rear: Cannot figure out which bootloader is used."
        )
        unsupported = Builtins.add(
          unsupported,
          _("Cannot figure out which bootloader is used.")
        )
      end

      deep_copy(unsupported)
    end

    # checks disc for
    #  - iscsi
    #  - multipath
    #  - mountby uuid
    #  - filesystem
    # returns error message if system is not supported, otherwise nil
    def SystemCheckDisk
      devicegraph = Y2Storage::StorageManager.instance.probed
      supportedfs = [:ext2, :ext3, :ext4, :tmpfs, :swap, :none, :nfs, :nfs4, :btrfs, :xfs]
      unsupported = []
      # Check rear version
      rear_cmd_ver = "/usr/sbin/rear -V | cut -d' ' -f2";
      out = SCR.Execute(path(".target.bash_output"), rear_cmd_ver);

      # version >=1.18 supports  vfat partitions
      if Gem::Version.new(Ops.get_string(out, "stdout", "")) >= Gem::Version.new("1.18")
        supportedfs.push(:vfat);
      end

      devicegraph.disk_devices.each do |device|
        # check devices
        if device.respond_to?(:transport) && device.transport.is?(:iscsi)
          Builtins.y2error("Not supported by rear: Device #{device.name} is iscsi.")
          unsupported << Builtins.sformat(_("Device %1 is iscsi."), device.name)
        end
        if device.is?(:multipath)
          Builtins.y2error("Not supported by rear: Device #{device.name} is multipath.")
          unsupported << Builtins.sformat(_("Device %1 is multipath."), device.name)
        end
        device.partitions.map(&:filesystem).compact.each do |filesystem|
          name = filesystem.plain_blk_devices.first.name
          type = filesystem.type

          @btrfs = true if type.is?(:btrfs)

          if !supportedfs.include?(type.to_sym)
            Builtins.y2error(
              "Not supported by rear: Partition #{name} uses an unsupported filesystem (#{type})."
            )
            unsupported << Builtins.sformat(
              _("Partition %1 uses an unsupported filesystem (%2)."), name, type.to_s
            )
          end
        end
      end

      deep_copy(unsupported)
    end

    def Btrfs?
      @btrfs
    end

    # runs all system checks
    # make sure to add your function call here if you add further checks
    # returns error message if system is not supported, otherwise nil

    def SystemCheck
      unsupported = []

      unsupported = Convert.convert(
        Builtins.merge(unsupported, SystemCheckDisk()),
        :from => "list",
        :to   => "list <string>"
      )
      unsupported = Convert.convert(
        Builtins.merge(unsupported, SystemCheckBootloader()),
        :from => "list",
        :to   => "list <string>"
      )

      deep_copy(unsupported)
    end

    publish :function => :SystemCheck, :type => "list <string> ()"
    publish :function => :Btrfs?, :type => "boolean ()"
  end

  RearSystemCheck = RearSystemCheckClass.new
  RearSystemCheck.main
end
