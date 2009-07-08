#
# concov - continuous coverage manager
#
#   * lib/config.rb: concov configuration manager
#

require "yaml"
require "pathname"

module Concov
  VERSION = "0.1"

  Config = Struct.new(
    :database_path,
    :header_html,
    :footer_html,
    :skip_files,
    :custom_query,
  ).new

  def Config.deploy(path)
    path ||= Dir.pwd + "/concov.conf"
    data = YAML.load_file(path)

    # database path
    path = Pathname(data["database_path"] || "data")
    Config.database_path = path.expand_path
    # deploy database
    Coverage.deploy

    Config.header_html = data["header_html"]
    Config.footer_html = data["footer_html"]
    Config.skip_files  = data["skip_files"] || []

    Config.custom_query = {}
    if data["custom_query"]
      data["custom_query"].each do |k, v|
        Config.custom_query[k] = v.each.with_object({}) do |(k, v), h|
          h[k.intern] = v
        end.freeze
      end
    end
  end
end
