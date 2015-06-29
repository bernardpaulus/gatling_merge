gatling_merge : SVN merge with a gatling gun!
=============================================

Automate the workflow when merging commit to/from a branch on svn

    merge <-.
      v     |
    build   |
      v     |
    commit -´

    
Sample usage
------------

Current directory is the barnch working copy:

    gatling_merge.sh load /path/to/trunk_working_copy 1234 1235
    gatling_merge.sh rapidfire 'make' # or whatever build command

Install
-------

Just download this directory. Even better, `git clone` the repo, start making your own changes and share them back :)

Required:
* a *bash* shell with the common unix rools.
* a *svn* client *with the command-line tools on your PATH*

Tip: add this directory to your PATH

Target platform is [msysgit](http://msysgit.github.io/), though this ought to run on a stock linux
