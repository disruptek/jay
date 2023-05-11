(declare-project
  :name "jay"
  :description ```like ray, but for janet```
  :license "GPL-3.0-or-later"
  :url "https://github.com/disruptek/jay"
  :repo "git+https://github.com/disruptek/jay.git"
  :dependencies
    ["https://github.com/janet-lang/spork"
     "https://github.com/disruptek/jurl"]
  :version "0.0.0")

(declare-source
  :prefix "jay"
  :source ["jay/init.janet" "jay/server.janet"
           "jay/aws.janet" "jay/lambda.janet"])
