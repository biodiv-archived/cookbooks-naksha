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

# setup solr
include_recipe "elasticsearch"

# setup geoserver
include_recipe "geoserver-tomcat"
include_recipe "geoserver-tomcat::postgresql"

# install grdle
include_recipe "gradle::tarball"
gradleCmd = "JAVA_HOME=#{node.java.java_home} gradle"
repo = "#{Chef::Config[:file_cache_path]}/naksha"
#additionalConfig = "#{node.naksha.additional_config}"

bash 'cleanup extracted naksha' do
   code <<-EOH
   rm -rf #{node.naksha.extracted}
   rm -f #{additionalConfig}
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
  notifies :create, "template[#{additionalConfig}]",:immediately
  #notifies :run, "bash[copy static files]",:immediately
end

bash 'copy static files' do
  code <<-EOH
  mkdir -p #{node.biodiv.data}/images
  cp -r #{node.biodiv.extracted}/web-app/images/* #{node.biodiv.data}/images
  chown -R tomcat:tomcat #{node.biodiv.data}
  EOH
  only_if "test -d #{node.biodiv.extracted}"
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
  yes | #{gradleCmd} war  #{node.naksha.war}
  chmod +r #{node.naksha.war}
  EOH

  not_if "test -f #{node.naksha.war}"
  only_if "test -f #{additionalConfig}"
  notifies :run, "bash[copy additional config]", :immediately
end

bash "copy additional config" do
# code <<-EOH
#  mkdir -p /tmp/biodiv-temp/WEB-INF/lib
#  mkdir -p ~tomcat/.grails
#  cp #{additionalConfig} ~tomcat/.grails
#  cp #{additionalConfig} /tmp/biodiv-temp/WEB-INF/lib
#  cd /tmp/biodiv-temp/
#  jar -uvf #{node.biodiv.war}  WEB-INF/lib
#  chmod +r #{node.biodiv.war}
#  #rm -rf /tmp/biodiv-temp
#  EOH
  notifies :enable, "cerner_tomcat[#{node.biodiv.tomcat_instance}]", :immediately
  action :nothing
end

#  create additional-config
template additionalConfig do
  source "biodiv-api.properties.erb"
  notifies :run, "bash[compile_naksha]"
  notifies :run, "bash[copy additional config]"
end

cerner_tomcat node.biodiv.tomcat_instance do
  version "7.0.54"
  web_app "biodiv-api" do
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
