#
# Cookbook Name:: biodiv
# Recipe:: default
#
# Copyright 2014, Strand Life Sciences
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
include_recipe "elasticsearch"

# setup geoserver
include_recipe "geoserver-tomcat"
include_recipe "geoserver-tomcat::postgresql"

include_recipe "gradle"
gradleCmd = "JAVA_HOME=#{node.java.java_home} #{node.naksha.extracted}/gradlew"
nakshaRepo = "#{Chef::Config[:file_cache_path]}/naksha"


bash 'cleanup extracted naksha' do
   code <<-EOH
   rm -rf #{node.naksha.extracted}
   EOH
   action :nothing
   notifies :run, 'bash[unpack naksha]'
end

# download git repository zip
remote_file node.naksha.download do
  source   node.naksha.link
  mode     0644
  notifies :run, 'bash[cleanup extracted naksha]',:immediately
end

bash 'unpack naksha' do
  code <<-EOH
  cd "#{node.naksha.directory}"
  unzip  #{node.naksha.download}
  expectedFolderName=`basename #{node.naksha.extracted} | sed 's/.zip$//'`
  folderName=`basename #{node.naksha.download} | sed 's/.zip$//'`

  if [ "$folderName" != "$expectedFolderName" ]; then
      mv "$folderName" "$expectedFolderName"
  fi
  EOH
  not_if "test -d #{node.naksha.extracted}"
  notifies :run, "bash[compile_naksha]"
end

# Setup user/group
poise_service_user "tomcat user" do
  user "tomcat"
  group "tomcat"
  shell "/bin/bash"
end

bash "compile_naksha" do
  code <<-EOH
  cd #{node.naksha.extracted}
  yes | #{gradleCmd} war
  chmod +r #{node.naksha.war}
  EOH

  not_if "test -f #{node.naksha.war}"
  notifies :enable, "cerner_tomcat[#{node.biodiv.tomcat_instance}]", :immediately
  action :nothing
end

cerner_tomcat node.biodiv.tomcat_instance do
  version "8.5.27"
  web_app "naksha" do
    source "file://#{node.naksha.war}"

#    template "META-INF/context.xml" do
#      source "biodiv.context.erb"
#    end
  end

  java_settings("-Xms" => "512m",
                "-D#{node.biodiv.appname}_CONFIG_LOCATION=".upcase => "#{node.biodiv.additional_config}",
                "-D#{node.biodivApi.appname}_CONFIG_LOCATION=".upcase => "#{node.biodivApi.additional_config}",
                "-D#{node.fileops.appname}_CONFIG=".upcase => "#{node.fileops.additional_config}",
                "-Dlog4jdbc.spylogdelegator.name=" => "net.sf.log4jdbc.log.slf4j.Slf4jSpyLogDelegator",
                "-Dfile.encoding=" => "UTF-8",
                "-Dorg.apache.tomcat.util.buf.UDecoder.ALLOW_ENCODED_SLASH=" => "true",
                "-Xmx" => "4g",
                "-XX:PermSize=" => "512m",
                "-XX:MaxPermSize=" => "512m",
                "-XX:+UseParNewGC" => "")

  action	:nothing
  only_if "test -f #{node.naksha.war}"
end
