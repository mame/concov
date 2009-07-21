= concov

* http://github.com/mame/concov/tree/master

== DESCRIPTION:

concov helps you comprehend continuous changes of coverage.

== FEATURES/PROBLEMS:


= SYNOPSIS:

demo: http://dame.dyndns.org:7001/


== REQUIREMENTS:

* ruby 1.9.1p129 or later
* ramaze / innate (> 2009.06.12)
* sequel (3.1.0)
* amalgalite

* thin (optional)

* rack-test (for spec)
* bacon (for spec)
* nokogiri (for spec)

== INSTALL:

* modify shebang of bin/concov

* modify concov.conf

* initialize database

  $ bin/concov init

* build coverage files by running tests of the target project with gcov

  $ cd /path/to/build/project/
  $ make
  $ make check

* register coverage files

  $ bin/concov register /path/to/coverage/files/

    or

  $ bin/concov register /path/to/coverage/files/ -d 20090101

* start concov webapp

  $ ramaze19 start

    or

  $ thin start

* view http://server:7000/ by your browser

== LICENSE:

Copyright (c) 2009 Yusuke Endoh <mame@tsg.ne.jp>, Nayuko Watanabe
