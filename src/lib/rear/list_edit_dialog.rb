# Copyright (c) 2017 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact Novell about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "yast"
require "ui/dialog"

Yast.import "UI"
Yast.import "Label"

module RearConfig
  class ListEditDialog < UI::Dialog
    def initialize(title, list)
      super()
      textdomain "rear"

      @title = title
      @list = list
    end

    def dialog_content
      MinSize(
        45,
        15,
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(0.5),
            VBox(
              VSquash(
                HBox(
                  InputField(Id(:entry), Opt(:hstretch), _("&New Entry")),
                  VBox(
                    VSpacing(1),
                    PushButton(Id(:additem), Yast::Label.AddButton)
                  )
                )
              ),
              HBox(
                SelectionBox(
                  Id(:list),
                  @title,
                  @list
                ),
                Top(
                  VBox(
                    VSpacing(1),
                    PushButton(Id(:delitem), Yast::Label.DeleteButton)
                  )
                )
              ),
              ButtonBox(
                PushButton(Id(:ok), Yast::Label.OKButton),
                PushButton(Id(:cancel), Yast::Label.CancelButton)
              )
            ),
            VSpacing(0.5)
          ),
          HSpacing(1)
        )
      )
    end

    def additem_handler
      addelem = Yast::UI.QueryWidget(Id(:entry), :Value)
      unless @list.include?(addelem)
        @list.push(addelem)
        Yast::UI.ChangeWidget(Id(:list), :Items, @list)
      end
    end

    def delitem_handler
      delelem = Yast::UI.QueryWidget(Id(:list), :CurrentItem)
      @list.delete(delelem)
      Yast::UI.ChangeWidget(Id(:list), :Items, @list)
    end

    def ok_handler
      finish_dialog(@list)
    end
  end
end
