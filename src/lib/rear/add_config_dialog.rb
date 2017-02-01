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
  class AddConfigDialog < UI::Dialog
    def initialize(message)
      super()
      textdomain "rear"

      @message = message
    end

    def dialog_content
      MinSize(
        50,
        20,
        HBox(
          HSpacing(1.5),
          VBox(
            HSpacing(50),
            VSpacing(0.5),
            Label(_("Your ReaR configuration needs to be modified.")),
            VSpacing(0.5),
            VBox(RichText(@message)),
            ButtonBox(
              PushButton(Id(:ok), Yast::Label.OKButton),
              PushButton(Id(:cancel), Yast::Label.CancelButton)
            ),
            VSpacing(0.5)
          ),
          HSpacing(1.5)
        )
      )
    end

    def ok_handler
      finish_dialog(true)
    end

    def cancel_handler
      finish_dialog(false)
    end
  end
end
