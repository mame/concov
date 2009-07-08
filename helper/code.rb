#
# concov - continuous coverage manager
#
#   * helper/code.rb: code markup
#

# speed up
module Rack
  module Utils
    module_function
    def escape_html(string)
      string.to_s.gsub(/[&<>'"]/, ESCAPE_HTML_HASH)
    end
    ESCAPE_HTML_HASH = {
      ?& => "&amp;",
      ?< => "&lt;",
      ?> => "&gt;",
      ?' => "&#39;",
      ?" => "&quot;",
    }
  end
end

module Innate
  module Helper
    module Code
      def code_markup(count, line)
        if line
          n = 0
          line = line.chomp.gsub(/\t/) do
            m = 8 - ($~.begin(0) + n) % 8
            n += m - 1
            " " * m
          end
          line.gsub!(/(?:\S){40,}/) { $&.gsub(/./, "\\0\u200b") }
          line = Rack::Utils.escape_html(line)
          line.gsub!("  ", "&nbsp; ")
          cls = count ? count > 0 ? "covered " : "uncovered " : ""
          count = count == 0 ? "#####" : count
          %(<td class="#{ cls }count">#{ count }</td>) <<
          %(<td class="#{ cls }code#{ " blank" unless count }">#{ line }</td>)
        else
          %(<td class="deleted" colspan="2"></td>)
        end
      end
    end
  end
end
