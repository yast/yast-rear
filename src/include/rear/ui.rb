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

# File:	include/rear/ui.ycp
# Package:	Configuration of rear
# Summary:	Dialogs definitions
# Authors:	Thomas Goettlicher <tgoettlicher@suse.de>
#
# $Id$

require "rear/list_edit_dialog"
require "rear/add_config_dialog"

module Yast
  module RearUiInclude
    # The defaults that are needed to get rear working with our setup (btrfs & snapper)
    # Those are taken from
    # https://github.com/rear/rear/blob/master/usr/share/rear/conf/examples/SLE12-SP2-btrfs-example.conf
    REQUIRED_PROGS = %w(snapper chattr lsattr)
    COPY_AS_IS = %w(/usr/lib/snapper/installation-helper /etc/snapper/config-templates/default)
    BACKUP_OPTIONS = "nfsvers=3,nolock"

    # This one looks really ugly. Unfortunately there is no other way to solve this, according to jsmeix
    # It might be worth a try to let the 'if' -part run here in yast and then either add just the
    # 'then' part here or the 'else' part (which basically is empty)
    POST_RECOVERY_SCRIPT = [
      'if snapper --no-dbus -r $TARGET_FS_ROOT get-config | grep -q "^QGROUP.*[0-9]/[0-9]" ; '\
      'then snapper --no-dbus -r $TARGET_FS_ROOT set-config QGROUP= ;'\
      ' snapper --no-dbus -r $TARGET_FS_ROOT setup-quota && echo snapper setup-quota done'\
      ' || echo snapper setup-quota failed ; '\
      'else echo snapper setup-quota not used ; '\
      'fi'
    ]

    # List of scripts that the module should offer to remove from POST_RECOVERY_SCRIPT.
    #
    # This is used to fix up a problem with older versions of yast-rear which output an incorrectly
    # escaped snapper quota snippet when writing it into the ReaR configuration file. The problem
    # appeared in the following versions: 3.2.0 (2017) .. 4.2.2 (2021). This logic can be removed at
    # some reasonable point in the future when it is expected all configuration files have been
    # likely already corrected.
    POST_RECOVERY_SCRIPT_REMOVE = [
      'if snapper --no-dbus -r $TARGET_FS_ROOT get-config | grep -q ^QGROUP.*[0-9]/[0-9] ; '\
      'then snapper --no-dbus -r $TARGET_FS_ROOT set-config QGROUP= ;'\
      ' snapper --no-dbus -r $TARGET_FS_ROOT setup-quota && echo snapper setup-quota done'\
      ' || echo snapper setup-quota failed ; '\
      'else echo snapper setup-quota not used ; '\
      'fi'
    ]

    def initialize_rear_ui(include_target)
      Yast.import "UI"

      textdomain "rear"

      Yast.import "Rear"
      Yast.import "RearSystemCheck"
      Yast.import "Label"
      Yast.import "Message"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "Service"
      Yast.import "Wizard"
      Yast.import "Progress"
      Yast.import "Confirm"
      Yast.import "Report"
    end

    # returns currently loaded kernel modules
    def UsedModules
      modules = []

      cmd = "/usr/bin/lsmod | /usr/bin/tail -n +2 | /usr/bin/cut -d ' ' -f1 | /usr/bin/tac | /usr/bin/tr -s '[:space:]' ' '"
      output = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd, ""))
      mods = Builtins.splitstring(Ops.get_string(output, "stdout", ""), " ")

      n = 1
      Builtins.foreach(mods) do |mod|
        if mod != ""
          #     modules = add(modules, `item(`id(mod), sformat("%1. %2",n,mod ))); n=n+1;
          modules = Builtins.add(
            modules,
            Item(Id(mod), Builtins.sformat("%1", mod))
          )
        end
        n = Ops.add(n, 1)
      end
      deep_copy(modules)
    end

    # returns a list of mountpoints that have to be included in BACKUP_PROG_INCLUDE
    def GetMountpoints
      cmd = "/usr/bin/findmnt --noheadings --raw --types btrfs "\
            "--output TARGET | /usr/bin/sort"
      output = SCR.Execute(path(".target.bash_output"), cmd, "")
      mountpoints = output["stdout"].split(/\n/)
      # kick out by default:
      # / - because it gets backed-up by default
      # /.snapshots and /var/crash - just bloat the backup
      mountpoints -= %w(/ /.snapshots /var/crash)
      mountpoints.map {|e| e + "/*" }
    end

    # Helper to compare two arrays
    #
    # Compare the value array with the default array. The action selects whether the default array
    # defines entries that are expected in the value array and should be added if missing (:add), or
    # are not desired and should be removed if present (:remove).
    #
    # @param value [Array<String>] current entries
    # @param default [Array<String>] entries that should appear (:add) or are not desired (:remove)
    #   in the value array
    # @param action [Symbol] operation mode (:add, :remove)
    # @return [String] list describing which entries need adding (:add) or removing (:remove)
    def ArrayChecker(value, default, action)
      if action == :add
        diff = default - value
      else
        raise ArgumentError, "action must be :add or :remove" if action != :remove
        diff = default & value
      end

      unless diff.empty?
        message =
          "<ul><li>" +
          diff.join("</li><li>") +
          "</li></ul>"
      end

      return message
    end

    # returns availible partitions on usb media
    def UsbPartitions
      Builtins.maplist(Rear.GetUsbPartitions) do |name, text|
        Item(Id(name), text)
      end
    end

    # Dialog shown, when system is not supported by rear
    def UnsupportedDialog(messages)
      messages = deep_copy(messages)
      message = Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              _("This system is not supported by rear, because:") + "<ul><li>",
              Builtins.mergestring(messages, "</li><li>")
            ),
            "</li></ul><strong>"
          ),
          _(
            "Do NOT expect the created backup to be useful for system recovery if you ignore this warning."
          )
        ),
        "</strong>"
      )

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1.5),
          VBox(
            HSpacing(50),
            VSpacing(0.5),
            Label(_("This system is not supported.")),
            VSpacing(0.5),
            VBox(RichText(message)),
            ButtonBox(
              PushButton(Id(:ok), _("&Ignore and continue")),
              PushButton(Id(:cancel), _("&Cancel"))
            ),
            VSpacing(0.5)
          ),
          HSpacing(1.5)
        )
      )

      ret = nil
      begin
        ret = Convert.to_symbol(UI.UserInput)
      end while ret != :ok && ret != :cancel

      UI.CloseDialog
      ret
    end

    # Dialog to Choose Directories
    def DirectoriesDialog(directories)
      directories = deep_copy(directories)
      # store original value of directories for the case that the users clicks cancel
      directories_sav = deep_copy(directories)

      UI.OpenDialog(
        MinSize(
          45,
          15,
          HBox(
            HSpacing(1),
            VBox(
              VSpacing(0.5),
              VBox(
                SelectionBox(
                  Id(:dirs),
                  _("Additional Directories to Backup"),
                  directories
                ),
                HBox(
                  PushButton(Id(:adddir), Label.AddButton),
                  HSpacing(4),
                  PushButton(Id(:deldir), Label.DeleteButton)
                ),
                ButtonBox(
                  PushButton(Id(:ok), _("&OK")),
                  PushButton(Id(:cancel), _("&Cancel"))
                )
              ),
              VSpacing(0.5)
            ),
            HSpacing(1)
          )
        )
      )

      ret = nil
      begin
        if ret == :deldir
          delelem = Convert.to_string(UI.QueryWidget(Id(:dirs), :CurrentItem))
          directories = Builtins.filter(directories) { |elem| elem != delelem }
          UI.ChangeWidget(Id(:dirs), :Items, directories)
        end
        if ret == :adddir
          addelem = UI.AskForExistingDirectory("/", _("Choose Directory"))
          if !Builtins.contains(directories, addelem)
            directories = Builtins.add(directories, addelem)
            UI.ChangeWidget(Id(:dirs), :Items, directories)
          end
        end
        ret = Convert.to_symbol(UI.UserInput)
      end while ret != :ok && ret != :cancel

      UI.CloseDialog

      return deep_copy(directories_sav) if ret == :cancel

      deep_copy(directories)
    end

    def SaveConfig(modules_load, backup_prog_include, post_recovery_script, required_progs, copy_as_is, backup_options)
      Rear.modified = true
      Rear.output = UI.QueryWidget(Id(:output), :Value)
      Rear.netfs_url = UI.QueryWidget(Id(:netfs_url), :Value)
      Rear.netfs_keep_old_backup = UI.QueryWidget(Id(:netfs_keep_old_backup), :Value)
      Rear.use_dhclient = UI.QueryWidget(Id(:use_dhclient), :Value)
      Rear.modules_load = modules_load
      Rear.backup_prog_include = backup_prog_include
      Rear.post_recovery_script = post_recovery_script
      Rear.required_progs = required_progs
      Rear.copy_as_is = copy_as_is
      Rear.backup_options = UI.QueryWidget(Id(:backup_options), :Value)

      if !Rear.Write
        Popup.Error(_("Cannot write rear configuration file."))
        return false
      end

      true
    end

    # Dialog to Choose Kernel Modules
    def KernelModulesDialog(modules)
      modules = deep_copy(modules)
      # store original value of modules for the case that the users clicks cancel
      modules_sav = deep_copy(modules)

      UI.OpenDialog(
        MinSize(
          50,
          20,
          HBox(
            HSpacing(1),
            VBox(
              VSpacing(0.5),
              Label(Opt(:boldFont), _("Additional Kernel Modules")),
              VSpacing(0.5),
              HBox(
                MinWidth(
                  30,
                  SelectionBox(
                    Id(:availablemods),
                    _("Available Modules in current System:"),
                    UsedModules()
                  )
                ),
                VBox(
                  VStretch(),
                  PushButton(Id(:delmod), Label.DeleteButton),
                  PushButton(Id(:addmod), UI.Glyph(:ArrowRight)),
                  VStretch(),
                  PushButton(Id(:up), UI.Glyph(:ArrowUp)),
                  PushButton(Id(:down), UI.Glyph(:ArrowDown)),
                  VStretch()
                ),
                MinWidth(
                  30,
                  SelectionBox(
                    Id(:mods),
                    _("Modules added to Rescue System:"),
                    modules
                  )
                )
              ),
              Label(_("Modules are sorted in the order they were loaded.")),
              ButtonBox(
                PushButton(Id(:ok), _("&OK")),
                PushButton(Id(:cancel), _("&Cancel"))
              ),
              VSpacing(1)
            ),
            HSpacing(1)
          )
        )
      )

      ret = nil
      begin
        if ret == :delmod
          delelem = Convert.to_string(UI.QueryWidget(Id(:mods), :CurrentItem))
          modules = Builtins.filter(modules) { |elem| elem != delelem }
          UI.ChangeWidget(Id(:mods), :Items, modules)
        end
        if ret == :addmod
          addelem = Convert.to_string(
            UI.QueryWidget(Id(:availablemods), :Value)
          )
          if !Builtins.contains(modules, addelem)
            modules = Builtins.add(modules, addelem)
            UI.ChangeWidget(Id(:mods), :Items, modules)
          end
          UI.ChangeWidget(Id(:mods), :Value, addelem)
        end
        if ret == :up || ret == :down
          mod = Convert.to_string(UI.QueryWidget(Id(:mods), :Value))
          pos = 0
          Builtins.foreach(modules) do |tmpmod|
            raise Break if Ops.get(modules, pos, "") == mod
            pos = Ops.add(pos, 1)
          end

          if Ops.greater_than(pos, 0) && ret == :up
            Ops.set(modules, pos, Ops.get(modules, Ops.subtract(pos, 1), ""))
            Ops.set(modules, Ops.subtract(pos, 1), mod)
          end

          if Ops.less_than(pos, Ops.subtract(Builtins.size(modules), 1)) &&
              ret == :down
            Ops.set(modules, pos, Ops.get(modules, Ops.add(pos, 1), ""))
            Ops.set(modules, Ops.add(pos, 1), mod)
          end


          UI.ChangeWidget(Id(:mods), :Items, modules)
          UI.ChangeWidget(Id(:mods), :Value, mod)
        end

        ret = Convert.to_symbol(UI.UserInput)
      end while ret != :ok && ret != :cancel

      UI.CloseDialog

      return deep_copy(modules_sav) if ret == :cancel

      deep_copy(modules)
    end



    # Dialog to run rear
    def RearRunDialog
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1.5),
          VSpacing(18),
          VBox(
            HSpacing(80),
            VSpacing(0.5),
            LogView(Id(:log), _("Rear output:"), 8, 0),
            VSpacing(0.5),
            ReplacePoint(Id(:rp), Label(_("Preparing for Rear Execution."))),
            VSpacing(0.5),
            PushButton(Id(:close), Label.CloseButton),
            VSpacing(0.5)
          ),
          HSpacing(1.5)
        )
      )

      UI.ChangeWidget(Id(:close), :Enabled, false)

      if !Package.Install("rear")
        Report.Error(Message.CannotContinueWithoutPackagesInstalled)
        UI.CloseDialog
        return :close
      end

      id = Convert.to_integer(
        # -v : verbose; without it rear runs completely silent
        SCR.Execute(path(".process.start_shell"), "/usr/sbin/rear -v mkbackup")
      )
      UI.ReplaceWidget(Id(:rp), Label(_("Running rear...")))

      ret = nil
      begin
        ret = Convert.to_symbol(UI.PollInput)

        if SCR.Read(path(".process.running"), id) != true
          buf = Convert.to_string(SCR.Read(path(".process.read"), id))
          err_buf = Convert.to_string(
            SCR.Read(path(".process.read_stderr"), id)
          )
          if buf != nil && buf != ""
            UI.ChangeWidget(Id(:log), :LastLine, Ops.add(buf, "\n"))
          end
          if err_buf != nil && err_buf != ""
            UI.ChangeWidget(Id(:log), :LastLine, Ops.add(err_buf, "\n"))
          end

          status = Convert.to_integer(SCR.Read(path(".process.status"), id))
          if status != 0
            UI.ReplaceWidget(
              Id(:rp),
              Label(
                Builtins.sformat(
                  _("Execution failed with return value %1."),
                  status
                )
              )
            )
          else
            UI.ReplaceWidget(
              Id(:rp),
              Label(
                _(
                  "Finished. You are strongly advised to test the created backup."
                )
              )
            )
          end
          UI.ChangeWidget(Id(:close), :Enabled, true)
          ret = Convert.to_symbol(UI.UserInput)
        else
          line = Convert.to_string(SCR.Read(path(".process.read_line"), id))
          if line != nil && line != ""
            UI.ChangeWidget(Id(:log), :LastLine, Ops.add(line, "\n"))
          end
          err = Convert.to_string(
            SCR.Read(path(".process.read_line_stderr"), id)
          )
          if err != nil && err != ""
            UI.ChangeWidget(Id(:log), :LastLine, Ops.add(err, "\n"))
          end
        end

        Builtins.sleep(100)
      end while ret != :close

      UI.CloseDialog
      ret
    end

    # Dialog for setup up Rear
    def RearConfigDialog
      # For translators: Caption of the dialog
      caption = _("Rear Configuration")

      # help text for Rear
      help = _(
        "<p>Configure Rear Relax and Recover (<b>ReaR</b>) backup for your computer.</p>"
      ) +
        _(
          "<p>Decide how to start your <b>Recovery System</b>. Choose USB if you want to boot from an USB stick, or ISO for CD-ROM respectively.</p>"
        ) +
        _(
          "<p>Choose where the <b>Backup</b> should be stored. Select NFS if you have to use a server that offers Network File System. Please specify the location as follows: <tt>nfs://hostname/directory</tt>. You can also choose USB to store your backup on an USB stick or USB disk.</p>"
        ) +
        _(
          "<p>If no USB devices are shown, attach an USB stick or an USB disk and click <b>Rescan USB Devices</b>.</p>"
        ) +
        _(
          "<p>Select <b>Keep old backup</b> if you don't want the previous backup copy to be overwritten.</p>"
        ) +
        _(
          "<p>The <b>Advanced</b> menu offers to add <b>additional directories to the backup</b> and <b>additional kernel modules to the rescue system</b>. That's only useful if your backup doesn't contain all the needed directories or the rescue system doesn't boot due to missing kernel modules.</p>"
        ) +
        _(
          "<p>The <b>Save and run rear now</b> button runs rear and shows rear's output. <strong>Make sure to test if the created backup works as expected on your system!</strong></p>"
        ) +
        _(
          "<p><b>OK</b> saves the configuration and quits while <b>Cancel</b> closes the configuration dialog without saving.<p>"
        )

      # get varibales from config
      netfs_url = [Rear.netfs_url]
      netfs_keep_old_backup = Rear.netfs_keep_old_backup
      use_dhclient = Rear.use_dhclient
      modules_load = Rear.modules_load
      backup_prog_include = Rear.backup_prog_include || []
      post_recovery_script = Rear.post_recovery_script || []
      required_progs = Rear.required_progs || []
      copy_as_is = Rear.copy_as_is || []
      backup_options = Rear.backup_options
      output = Rear.output
      mountpoints = GetMountpoints()
      message = ""

      # Set defaults:
      # This is not mandatory, so we only set it, if empty
      backup_options = BACKUP_OPTIONS if backup_options.empty?

      if RearSystemCheck.Btrfs?
        msg = ArrayChecker(backup_prog_include, mountpoints, :add)
        message += _("Additional directories in the backup:") + msg if msg
      end

      msg = ArrayChecker(required_progs, REQUIRED_PROGS, :add)
      message += _("Additional programs in the rescue system:") + msg if msg

      msg = ArrayChecker(copy_as_is, COPY_AS_IS, :add)
      message += _("Additional files to be copied into the rescue system:") + msg if msg

      msg = ArrayChecker(post_recovery_script, POST_RECOVERY_SCRIPT_REMOVE, :remove)
      message += _("Removal of malformed post recovery scripts:") + msg if msg

      msg = ArrayChecker(post_recovery_script, POST_RECOVERY_SCRIPT, :add)
      message += _("Additional post recovery scripts:") + msg if msg

      unless message.empty?
        message =
          "<p>" + _("YaST would like to change your ReaR configuration.") + "</p>" +
          message +
          "<strong>" + 
          _("You might end up in an unusable backup if you don't accept this.") +
          "</strong>"

        if RearConfig::AddConfigDialog.new(message).run
          # Add the important elements to the existing config array:
          backup_prog_include |= mountpoints
          required_progs |= REQUIRED_PROGS
          copy_as_is |= COPY_AS_IS
          post_recovery_script -= POST_RECOVERY_SCRIPT_REMOVE
          post_recovery_script |= POST_RECOVERY_SCRIPT
        else
          Builtins.y2warning("User did not accept the config changes we suggested.")
        end
      end

      # set available options
      nfslocation = ["nfs://hostname/directory"]
      backup_type = ["NFS", "USB"]
      outputlist = ["ISO", "USB"]

      # prepare advanced menu
      expertMenu = [
        Item(
          Id(:additionalDirs),
          _("Additional Directories in Backup")
        ),
        Item(
          Id(:additionalModules),
          _("Additional Kernel Modules in Rescue System")
        ),
        Item(
          Id(:requiredProgs),
          _("Required Programs")
        ),
        Item(
          Id(:copyAsIs),
          _("Copy As Is")
        ),
        Item(
          Id(:postRecoveryScript),
          _("Post Recovery Script")
        )
      ]

      # prepare main dialog
      con = HBox(
        HSpacing(3),
        VBox(
          VSpacing(),
          Frame(
            _("Recovery System"),
            HBox(
              HSpacing(),
              VBox(
                VSpacing(0.5),
                ComboBox(
                  Id(:output),
                  Opt(:notify, :hstretch),
                  _("&Boot Media"),
                  outputlist
                ),
                VSpacing(0.5)
              ),
              HSpacing()
            )
          ),
          VSpacing(1.5),
          Frame(
            _("Backup"),
            HBox(
              HSpacing(),
              VBox(
                VSpacing(0.5),
                ComboBox(
                  Id(:backup_type),
                  Opt(:notify, :hstretch),
                  _("&Backup Media"),
                  backup_type
                ),
                VSpacing(0.5),
                ReplacePoint(
                  Id(:rp),
                  ComboBox(
                    Id(:netfs_url),
                    Opt(:notify, :hstretch, :editable),
                    _("&Location"),
                    netfs_url
                  )
                ),
                VSpacing(0.5),
                HBox(
                  Left(
                    HBox(
                      CheckBox(
                        Id(:netfs_keep_old_backup),
                        Opt(:notify),
                        _("&Keep old backup"),
                        netfs_keep_old_backup
                      ),
                      Left(
                        CheckBox(
                          Id(:use_dhclient),
                          Opt(:notify),
                          _("Use &dhclient"),
                          use_dhclient
                        )
                      )
                    )
                  ),
                  PushButton(Id(:scanusb), _("Rescan USB Devices"))
                ),
                VSpacing(0.5),
                TextEntry(Id(:backup_options), Opt(:notify), _("&Backup Options"), backup_options)
              ),
              HSpacing()
            )
          ),
          VSpacing(0.5),
          Right(MenuButton(_("Advanced"), expertMenu)),
          VSpacing(0.5),
          PushButton(Id(:runrear), _("Save and run rear now")),
          VStretch()
        ),
        HSpacing(3)
      )


      Wizard.SetContents(caption, con, help, true, true)


      # If config file was manually edited and config options are unknown we show a warning
      config_conflicts = false
      conflict_message = ""


      # set settings according to options read from config file.
      if Rear.backup != "NETFS" && Rear.backup != ""
        config_conflicts = true
        conflict_message = Ops.add(
          conflict_message,
          _("BACKUP is set to an unknown value.\n")
        )
      end

      # choose selected option or fallback to "ISO" if nothing is set
      if Builtins.contains(outputlist, output)
        UI.ChangeWidget(Id(:output), :Value, output)
      elsif output == ""
        UI.ChangeWidget(Id(:output), :Value, "ISO")
      else
        config_conflicts = true
        conflict_message = Ops.add(
          conflict_message,
          _("OUTPUT is set to an unknown value.\n")
        )
      end

      type = Builtins.toupper(Builtins.substring(Rear.netfs_url, 0, 3))
      if Builtins.contains(Builtins.add(backup_type, ""), type)
        UI.ChangeWidget(Id(:backup_type), :Value, type)
        if type == "NFS"
          if !Builtins.contains(nfslocation, Rear.netfs_url)
            nfslocation = Builtins.prepend(nfslocation, Rear.netfs_url)
          end
          UI.ChangeWidget(Id(:netfs_url), :Items, nfslocation)
        end
      else
        config_conflicts = true
        conflict_message = Ops.add(
          conflict_message,
          _("NETFS_URL is set to an unknown value or in wrong format.\n")
        )
      end


      if config_conflicts &&
          !Popup.ContinueCancel(
            Ops.add(
              Ops.add(
                _(
                  "Your rear configuration file contains options this YaST2 module cannot configure.\n"
                ),
                conflict_message
              ),
              _("Do you want to continue and overwrite these settings?")
            )
          )
        return :abort
      end

      # this flag ensures that the combox is correctly
      # refilled when the USB/NFS combobox is changed
      rebuild_combobox_flag = false

      ret = nil
      begin
        if UI.QueryWidget(Id(:backup_type), :Value) == "USB" &&
            rebuild_combobox_flag == false
          UI.ReplaceWidget(
            Id(:rp),
            ComboBox(
              Id(:netfs_url),
              Opt(:notify, :hstretch),
              _("&Location"),
              UsbPartitions()
            )
          )
          rebuild_combobox_flag = true
        end

        if Convert.to_string(UI.QueryWidget(Id(:backup_type), :Value)) == "NFS" &&
            rebuild_combobox_flag == true
          UI.ReplaceWidget(
            Id(:rp),
            ComboBox(
              Id(:netfs_url),
              Opt(:notify, :hstretch, :editable),
              _("&Location"),
              nfslocation
            )
          )
          rebuild_combobox_flag = false
        end

        # open run rear dialg, if usb boot medium is selected show a warning
        if ret == :runrear
          if "USB" != Convert.to_string(UI.QueryWidget(Id(:output), :Value)) ||
              Popup.ContinueCancel(
                _(
                  "Your USB medium will be overwritten. Do you want to continue?"
                )
              )
            SaveConfig(modules_load, backup_prog_include, post_recovery_script, required_progs, copy_as_is, backup_options)
            RearRunDialog()
          end
        end

        if ret == :scanusb
          if UI.QueryWidget(Id(:backup_type), :Value) == "USB"
            UI.ChangeWidget(Id(:netfs_url), :Items, UsbPartitions())
          end
        end

        # handle advanced menu
        if ret == :additionalModules
          modules_load = KernelModulesDialog(modules_load)
        end

        if ret == :additionalDirs
          backup_prog_include = DirectoriesDialog(backup_prog_include)
        end

        if ret == :requiredProgs
          list = RearConfig::ListEditDialog.new(_("Required Programs"), required_progs).run
          required_progs = list if list
        end

        if ret == :copyAsIs
          list = RearConfig::ListEditDialog.new(_("Copy As Is"), copy_as_is).run
          copy_as_is = list if list
        end

        if ret == :postRecoveryScript
          list = RearConfig::ListEditDialog.new(_("Post Recovery Script"), post_recovery_script).run
          post_recovery_script = list if list
        end

        ret = Convert.to_symbol(UI.UserInput)
      end while !Builtins.contains([:back, :abort, :cancel, :next, :ok], ret)

      if ret == :next || ret == :ok
        SaveConfig(modules_load, backup_prog_include, post_recovery_script, required_progs, copy_as_is, backup_options)
      end

      ret
    end


    # The whole sequence
    def RearSequence
      Wizard.OpenOKDialog
      Wizard.SetDesktopTitleAndIcon("org.opensuse.yast.Rear")

      if !Confirm.MustBeRoot
        UI.CloseDialog
        return :abort
      end

      # Rear read dialog caption
      caption = _("Reading Rear Configuration")
      steps = 2

      Progress.New(
        caption,
        " ",
        steps,
        [_("Analyzing system"), _("Reading rear settings")],
        [_("Analyzing system..."), _("Reading rear settings..."), _("Finished")],
        ""
      )

      Progress.NextStage

      system_check_messages = RearSystemCheck.SystemCheck

      if system_check_messages != []
        Builtins.y2warning("This system is not supported by rear!")
        if UnsupportedDialog(system_check_messages) == :ok
          Builtins.y2milestone(
            "It was the user's decision to use rear although this system is not supported."
          )
        else
          Builtins.y2milestone(
            "User decided to quit yast2-rear because this system is not suported."
          )
          return :abort
        end
      end

      Progress.NextStage

      Rear.Read

      Progress.NextStage

      ret = RearConfigDialog()
      Rear.Write if ret == :next || ret == :ok

      UI.CloseDialog
      ret
    end
  end
end
