expand!

default[:naksha][:version]   = "master"
default[:naksha][:appname]   = "naksha"
default[:naksha][:repository]   = "naksha"
default[:naksha][:directory] = "/usr/local/src"

default[:naksha][:link]      = "https://codeload.github.com/strandls/#{naksha.repository}/zip/#{naksha.version}"
default[:naksha][:extracted] = "#{naksha.directory}/#{naksha.appname}-#{naksha.version}"
default[:naksha][:war]       = "#{naksha.extracted}/build/libs/naksha.war"
default[:naksha][:download]  = "#{naksha.directory}/#{naksha.repository}-#{naksha.version}.zip"

default[:naksha][:home] = "/usr/local/naksha"


