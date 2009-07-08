#
# concov - continuous coverage manager
#
#   * lib/git.rb: git interface
#

module Concov
  # this code is slightly ad-hoc...
  class Git
    class GitError < StandardError; end

    def init
      run("init")
    end

    def reset
      run("reset", "--mixed")
    end

    def add(*argv)
      argv = argv.map {|x| x.relative_path_from(@work_tree) }
      run("add", *argv)
    end

    def rm(*argv)
      argv = argv.map {|x| x.relative_path_from(@work_tree) }
      run("rm", "-r", "--cached", *argv)
    end

    def commit(msg)
      run("commit", "-a", "--allow-empty", "-m", msg)
    end

    def tag(tag)
      run("tag", tag)
    end

    def diff_index(path, tag, &blk)
      if path
        run("diff-index", *DIFF_OPTIONS, tag, "--cached", "--", path, &blk)
      else
        run("diff-index", tag, "--numstat", "--cached", "--", &blk)
      end
    end

    def diff_tree(path, tag1, tag2, &blk)
      run("diff-tree", *DIFF_OPTIONS, tag1, tag2, "--", path, &blk)
    end

    DIFF_OPTIONS = %w(--ignore-space-change --unified=1000000000 --no-color)

    def cat_file(path, tag, &blk)
      run("cat-file", "blob", tag + ":" + path.to_s, &blk)
    end

    def version
      @version ||= run("version")
    end

    private

    def initialize(git_dir, work_dir, git = "git")
      @git = git
      @git_dir = git_dir
      @work_tree = work_dir
    end

    def run(*argv)
      argv = [@git, "--git-dir", @git_dir, "--work-tree", @work_tree, *argv]
      argv = argv.compact.map {|x| x.to_s }
      out_rd, out_wr = IO.pipe("ASCII-8BIT")
      err_rd, err_wr = IO.pipe("ASCII-8BIT")
      pid = spawn(*argv, in: :close, out: out_wr, err: err_wr)
      out_wr.close
      err_wr.close
      block_given? ? yield(out_rd) : out_rd.read
    ensure
      out_rd.read
      stderr = err_rd.read
      pid, status = Process.waitpid2(pid)
      raise GitError, stderr unless status.success?
    end
  end
end
