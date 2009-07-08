#
# concov - continuous coverage manager
#
#   * helper/icon.rb: icon manager
#

module Innate
  module Helper
    module Icon
      DATE_NAVIGATIONS = [
        ["le", "first day"],
        ["l2", "previous week"],
        ["l1", "previous day"],
        ["r1", "next day"],
        ["r2", "next week"],
        ["re", "latest day"],
      ]

      CHANGES_NAVIGATIONS = [
        ["u2", "newer"],
        ["d2", "older"],
      ]

      CHANGES_DETAILS = {
        [:dir , :added   ] => "af",
        [:dir , :deleted ] => "df",
        [:dir , :modified] => "mf",
        [:file, :added   ] => "al",
        [:file, :deleted ] => "dl",
      }

      module_function

      def icon_img(file, title)
        %(<img class="icon" src="/icon/#{ file }" ) +
        %(alt="#{ title }" title="#{ title }" />)
      end

      def view_icon(view)
        icon_img("#{ view }.png", view.to_s)
      end

      def date_navi_icons(avails)
        DATE_NAVIGATIONS.zip(avails).map do |(file, alt), available|
          file = "arrow_#{ file }#{ available ? "" : "-d" }.png"
          icon_img(file, alt)
        end
      end

      def changes_navi_icon(side)
        side, alt = CHANGES_NAVIGATIONS[side == :newer ? 0 : 1]
        icon_img("arrow_#{ side }.png", alt)
      end

      def changes_detail_icon(type, event, alt)
        mark = CHANGES_DETAILS[[type, event]]
        icon_img("change_#{ mark }.png", alt)
      end
    end
  end
end
