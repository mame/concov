#
# concov - continuous coverage manager
#
#   * model/migrations.rb: schema migrations
#

require "sequel/extensions/migration"

module Concov
  class CreateDatabase < Sequel::Migration
    def up
      # file entries
      create_table :files do
        # source code information
        date :date      # source code revision
        text :dir       # directory in which source code is
        text :file      # filename of source code

        # filtering information (for speed)
        text :ext       # extension of filename
        text :adapter   # parser (gcov, rbcov, etc.)

        # coverage metrics (these are all nil when mark entry of deleted file)
        blob :coverage  # coverage of source code
        int  :hit       # number of covered lines
        int  :found     # number of covered and uncovered lines

        # difference to previous date
        int  :change    # reference to change
      end
      add_index :files, [:file, :date]
      add_index :files, :date

      # directory entries
      create_table :directories do
        # source code information
        date :date      # source code revision
        text :dir       # directory name

        # filtering information
        text :ext       # extension of filename
        text :adapter   # parser (gcov, rbcov, etc.)

        # coverage metrics
        int  :hit       # sum of number of covered lines
        int  :found     # sum of number of covered and uncovered lines

        # difference to previous date
        int  :change    # reference to change
      end
      add_index :directories, [:dir, :date]
      add_index :directories, :date

      # coverage changes
      create_table :changes do
        primary_key :id

        # difference to previous date
        int  :changed   # number of files whose coverage is changed
        int  :modified  # number of files that is modified
        int  :created   # number of files that is created
        int  :deleted   # number of files that is deleted
        int  :code_inc  # number of lines added
        int  :code_dec  # number of lines deleted
        int  :cov_inc   # number of lines newly covered
        int  :cov_dec   # number of lines no longer covered
      end

      # lock
      create_table :lock do
        int :dummy
      end
    end

    def down
      drop_index :files, [:file, :date]
      drop_index :files, :date
      drop_table :files
      drop_index :directories, [:dir, :date]
      drop_index :directories, :date
      drop_table :directories
      drop_table :changes
    end
  end
end
